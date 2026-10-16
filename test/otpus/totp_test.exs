defmodule OtpusTest.TOTPTest do
  use ExUnit.Case, async: true

  alias Otpus.TOTP

  # RFC 6238 Appendix B test secrets (ASCII bytes).
  @sha1_secret "12345678901234567890"
  @sha256_secret "12345678901234567890123456789012"
  @sha512_secret "1234567890123456789012345678901234567890123456789012345678901234"

  describe "code/3 against RFC 6238 Appendix B vectors" do
    test "SHA1, 8 digits, period 30" do
      for {time, expected} <- [
            {59, "94287082"},
            {1_111_111_109, "07081804"},
            {1_111_111_111, "14050471"},
            {1_234_567_890, "89005924"},
            {2_000_000_000, "69279037"},
            {20_000_000_000, "65353130"}
          ] do
        assert TOTP.code(@sha1_secret, time, digits: 8) == expected
      end
    end

    test "SHA256, 8 digits" do
      assert TOTP.code(@sha256_secret, 59, digits: 8, algorithm: :sha256) == "46119246"
    end

    test "SHA512, 8 digits" do
      assert TOTP.code(@sha512_secret, 59, digits: 8, algorithm: :sha512) == "90693936"
    end
  end

  describe "code/3 defaults" do
    test "defaults to 6 digits and period 30, zero-padding on the left" do
      # 07081804 truncated to 6 digits is 081804, which must keep its leading zero.
      assert TOTP.code(@sha1_secret, 1_111_111_109) == "081804"
    end

    test "honours a custom period" do
      # With period 60, time 119 is counter 1; with period 30, time 60 is counter 2.
      # Different counters must give different codes, same counter the same code.
      assert TOTP.code(@sha1_secret, 119, period: 60) == TOTP.code(@sha1_secret, 60, period: 60)
      refute TOTP.code(@sha1_secret, 119, period: 60) == TOTP.code(@sha1_secret, 120, period: 60)
    end
  end

  describe "decode_base32/1" do
    test "decodes a padded upper-case secret" do
      assert TOTP.decode_base32("JBSWY3DPEHPK3PXP") ==
               {:ok, "Hello!" <> <<0xDE, 0xAD, 0xBE, 0xEF>>}
    end

    test "tolerates lower case, spaces and dashes as authenticator apps print them" do
      assert TOTP.decode_base32("jbsw y3dp-ehpk 3pxp") ==
               {:ok, "Hello!" <> <<0xDE, 0xAD, 0xBE, 0xEF>>}
    end

    test "tolerates missing padding" do
      # "ME" is the unpadded base32 of a single byte "a".
      assert TOTP.decode_base32("ME") == {:ok, "a"}
    end

    test "names the first character outside the base32 alphabet" do
      assert TOTP.decode_base32("JBSW1Y3D0P") == {:error, {:character, "1"}}
    end

    test "names a non-ASCII character whole" do
      assert TOTP.decode_base32("JBSWé3DP") == {:error, {:character, "é"}}
    end

    test "reports invalid UTF-8 as a replacement character" do
      assert TOTP.decode_base32(<<"JBSW", 0xFF, "3DP">>) == {:error, {:character, "\uFFFD"}}
    end

    test "rejects a length no base32 key can have" do
      assert TOTP.decode_base32("me3324") == {:error, :length}
    end

    test "rejects an empty secret" do
      assert TOTP.decode_base32("") == {:error, :length}
    end
  end

  describe "remaining/2" do
    test "counts down to the next period boundary" do
      assert TOTP.remaining(59, 30) == 1
      assert TOTP.remaining(60, 30) == 30
      assert TOTP.remaining(75, 30) == 15
    end
  end
end
