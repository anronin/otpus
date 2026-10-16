defmodule Otpus.TOTP do
  @moduledoc """
  Time-based one-time passwords (RFC 6238) on top of HOTP (RFC 4226).

  Pure functions only: the caller supplies the Unix time, so every code
  is reproducible and testable against the RFC vectors.
  """

  import Bitwise, only: [&&&: 2]

  @type algorithm :: :sha | :sha256 | :sha512

  @doc """
  Returns the code for a raw binary secret at `unix_time` seconds.

  Options: `:digits` (default 6), `:period` (default 30), `:algorithm`
  (`:sha`, `:sha256` or `:sha512`, default `:sha`).
  """
  @spec code(binary, non_neg_integer, keyword) :: String.t()
  def code(secret, unix_time, opts \\ []) when is_binary(secret) and is_integer(unix_time) do
    digits = Keyword.get(opts, :digits, 6)
    period = Keyword.get(opts, :period, 30)
    algorithm = Keyword.get(opts, :algorithm, :sha)

    counter = div(unix_time, period)
    hmac = :crypto.mac(:hmac, algorithm, secret, <<counter::64>>)

    # Dynamic truncation (RFC 4226 §5.3): low nibble of the last byte picks
    # a 4-byte window; mask the top bit; reduce modulo 10^digits.
    offset = :binary.last(hmac) &&& 0x0F
    <<_::1, truncated::31>> = binary_part(hmac, offset, 4)

    truncated
    |> rem(Integer.pow(10, digits))
    |> Integer.to_string()
    |> String.pad_leading(digits, "0")
  end

  @doc "Seconds until the current period ends."
  @spec remaining(non_neg_integer, pos_integer) :: pos_integer
  def remaining(unix_time, period) when is_integer(unix_time) and period > 0 do
    period - rem(unix_time, period)
  end

  @doc """
  Decodes a base32 secret as authenticator apps print it: any case,
  with or without padding, spaces or dashes allowed between groups.
  """
  @spec decode_base32(String.t()) :: {:ok, binary} | {:error, {:character, String.t()} | :length}
  def decode_base32(secret) when is_binary(secret) do
    secret
    |> String.replace(~r/[\s\-]/, "")
    |> String.trim_trailing("=")
    |> decode_cleaned()
  end

  defp decode_cleaned(""), do: {:error, :length}

  defp decode_cleaned(cleaned) do
    case invalid_character(cleaned) do
      nil ->
        cleaned
        |> Base.decode32(case: :mixed, padding: false)
        |> length_error()

      character ->
        {:error, {:character, character}}
    end
  end

  defp invalid_character(text) do
    if String.valid?(text) do
      ~r/[^a-z2-7]/iu
      |> Regex.run(text)
      |> first_match()
    else
      "\uFFFD"
    end
  end

  defp first_match(nil), do: nil
  defp first_match([character]), do: character

  defp length_error({:ok, binary}), do: {:ok, binary}
  defp length_error(:error), do: {:error, :length}
end
