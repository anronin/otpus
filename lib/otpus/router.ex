defmodule Otpus.Router do
  @moduledoc """
  Two routes: the page, and a JSON endpoint the page polls once a second.
  """

  use Plug.Router

  alias Otpus.TOTP

  plug(:match)
  plug(:dispatch)

  @index_path Path.join(:code.priv_dir(:otpus), "index.html")
  @external_resource @index_path
  @index File.read!(@index_path)

  @algorithms %{"SHA1" => :sha, "SHA256" => :sha256, "SHA512" => :sha512}

  get "/" do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, @index)
  end

  get "/code" do
    conn = fetch_query_params(conn)

    with {:ok, secret} <- secret(conn.params),
         {:ok, digits} <- int(conn.params, "digits", 6, 4..10),
         {:ok, period} <- int(conn.params, "period", 30, 1..300),
         {:ok, algorithm} <- algorithm(conn.params) do
      now = System.os_time(:second)
      code = TOTP.code(secret, now, digits: digits, period: period, algorithm: algorithm)
      remaining = TOTP.remaining(now, period)
      json(conn, 200, ~s({"code":"#{code}","period":#{period},"remaining":#{remaining}}))
    else
      {:error, field, message} ->
        json(conn, 400, ~s({"error":"#{escape(message)}","field":"#{field}"}))
    end
  end

  match _ do
    send_resp(conn, 404, "not found")
  end

  defp secret(params) do
    params
    |> Map.get("secret", "")
    |> TOTP.decode_base32()
    |> secret_result()
  end

  defp secret_result({:ok, binary}), do: {:ok, binary}

  defp secret_result({:error, {:character, character}}) do
    {:error, "secret", "#{character} isn’t allowed in a key"}
  end

  defp secret_result({:error, :length}), do: {:error, "secret", "This key looks incomplete."}

  defp int(params, key, default, range) do
    params
    |> Map.get(key, "")
    |> parse_int(key, default, range)
  end

  defp parse_int("", _key, default, _range), do: {:ok, default}

  defp parse_int(value, key, _default, range) do
    value
    |> Integer.parse()
    |> check_range(key, range)
  end

  defp check_range({n, ""}, _key, first..last//_) when n >= first and n <= last, do: {:ok, n}

  defp check_range(_parsed, key, first..last//_) do
    {:error, key, "#{key} must be a whole number between #{first} and #{last}"}
  end

  defp algorithm(params) do
    params
    |> algorithm_name()
    |> fetch_algorithm()
  end

  defp algorithm_name(params) do
    params
    |> Map.get("algorithm", "SHA1")
    |> String.upcase()
  end

  defp fetch_algorithm(name) when is_map_key(@algorithms, name), do: {:ok, @algorithms[name]}

  defp fetch_algorithm(_name) do
    {:error, "algorithm", "algorithm must be one of #{algorithm_names()}"}
  end

  defp algorithm_names do
    @algorithms
    |> Map.keys()
    |> Enum.join(", ")
  end

  defp escape(text) do
    for <<char::utf8 <- text>>, into: "", do: escape_char(char)
  end

  defp escape_char(?"), do: ~S(\")
  defp escape_char(?\\), do: ~S(\\)

  defp escape_char(char) when char < 0x20 do
    "\\u" <> String.pad_leading(Integer.to_string(char, 16), 4, "0")
  end

  defp escape_char(char), do: <<char::utf8>>

  defp json(conn, status, body) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, body)
  end
end
