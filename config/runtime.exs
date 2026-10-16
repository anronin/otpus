import Config

if port = System.get_env("PORT") do
  config :otpus, port: String.to_integer(port)
end
