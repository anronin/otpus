defmodule OtpusTest.RouterTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  alias Otpus.Router
  alias Otpus.TOTP

  @opts Router.init([])
  @secret "JBSWY3DPEHPK3PXP"

  defp get(path) do
    conn(:get, path) |> Router.call(@opts)
  end

  @code_body ~r/\A\{"code":"(\d+)","period":(\d+),"remaining":(\d+)\}\z/
  @error_body ~r/\A\{"error":"((?:[^"\\]|\\.)*)","field":"(\w+)"\}\z/

  defp json(conn) do
    assert ["application/json; charset=utf-8"] = get_resp_header(conn, "content-type")

    case Regex.run(@code_body, conn.resp_body) do
      [_, code, period, remaining] ->
        %{
          "code" => code,
          "period" => String.to_integer(period),
          "remaining" => String.to_integer(remaining)
        }

      nil ->
        assert [_, error, field] = Regex.run(@error_body, conn.resp_body),
               "unexpected JSON body: #{conn.resp_body}"

        %{"error" => error, "field" => field}
    end
  end

  describe "GET /" do
    test "serves the single page" do
      conn = get("/")
      assert conn.status == 200
      assert ["text/html; charset=utf-8"] = get_resp_header(conn, "content-type")
      assert conn.resp_body =~ "Otpus"
    end
  end

  describe "GET /code" do
    test "returns the current code and seconds remaining" do
      conn = get("/code?secret=#{@secret}")
      assert conn.status == 200
      body = json(conn)

      now = System.os_time(:second)
      {:ok, raw} = TOTP.decode_base32(@secret)
      # Allow for the clock ticking between the request and this assertion.
      assert body["code"] in [TOTP.code(raw, now), TOTP.code(raw, now - 1)]
      assert body["remaining"] in 1..30
      assert body["period"] == 30
    end

    test "honours digits, period and algorithm" do
      conn = get("/code?secret=#{@secret}&digits=8&period=60&algorithm=SHA256")
      body = json(conn)
      assert String.length(body["code"]) == 8
      assert body["period"] == 60
      assert body["remaining"] in 1..60

      now = System.os_time(:second)
      {:ok, raw} = TOTP.decode_base32(@secret)
      opts = [digits: 8, period: 60, algorithm: :sha256]
      assert body["code"] in [TOTP.code(raw, now, opts), TOTP.code(raw, now - 1, opts)]
    end

    test "tolerates spaces and lower case in the secret" do
      assert get("/code?secret=jbsw+y3dp+ehpk+3pxp").status == 200
    end

    test "rejects a secret with characters base32 can't have" do
      conn = get("/code?secret=not-base32-1")
      assert conn.status == 400

      assert json(conn) == %{
               "error" => "1 isn’t allowed in a key",
               "field" => "secret"
             }
    end

    test "escapes the named character so the JSON stays valid" do
      assert %{"error" => ~S(\" isn’t allowed in a key)} = json(get("/code?secret=AB%22CD"))
      assert %{"error" => ~S(\\ isn’t allowed in a key)} = json(get("/code?secret=AB%5CCD"))
      assert %{"error" => ~S(\u0001 isn’t allowed in a key)} = json(get("/code?secret=AB%01CD"))
    end

    test "says a secret with an impossible length looks incomplete" do
      conn = get("/code?secret=me3324")
      assert conn.status == 400
      assert json(conn) == %{"error" => "This key looks incomplete.", "field" => "secret"}
    end

    test "rejects a missing secret with 400" do
      conn = get("/code")
      assert conn.status == 400
      assert %{"field" => "secret"} = json(conn)
    end

    test "rejects out-of-range digits and period" do
      assert %{"field" => "digits"} = json(get("/code?secret=#{@secret}&digits=20"))
      assert %{"field" => "digits"} = json(get("/code?secret=#{@secret}&digits=abc"))
      assert %{"field" => "period"} = json(get("/code?secret=#{@secret}&period=0"))
    end

    test "rejects an unknown algorithm" do
      conn = get("/code?secret=#{@secret}&algorithm=MD5")
      assert conn.status == 400
      assert %{"error" => error, "field" => "algorithm"} = json(conn)
      assert error =~ "algorithm"
    end
  end

  test "unknown paths are 404" do
    assert get("/nope").status == 404
  end
end
