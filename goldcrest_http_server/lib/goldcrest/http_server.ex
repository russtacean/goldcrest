defmodule Goldcrest.HTTPServer do
  @moduledoc """
  Starts a HTTP server on the given port
  This server also logs all requests
  """
  require Logger

  @server_options [
    active: false,
    packet: :http_bin,
    reuseaddr: true
  ]

  def start(port) do
    ensure_configured!()

    case :gen_tcp.listen(port, @server_options) do
      {:ok, socket} ->
        Logger.info("Listening on port #{port}")
        listen(socket)

      {:error, reason} ->
        Logger.error("Failed to start server on port #{port}: #{reason}")
    end
  end

  defp ensure_configured!() do
    case responder() do
      nil -> raise "No `responder` configured for `goldcrest_http_server"
      _responder -> :ok
    end
  end

  def listen(sock) do
    {:ok, req} = :gen_tcp.accept(sock)

    {
      :ok,
      {_http_req, method, {_type, path}, _v}
    } = :gen_tcp.recv(req, 0)

    Logger.info("Received HTTP request #{method} at #{path}")
    spawn(__MODULE__, :respond, [req, method, path])
    listen(sock)
  end

  def respond(req, method, path) do
    %Goldcrest.HTTPResponse{} =
      resp = responder().resp(req, method, path)

    resp_string = Goldcrest.HTTPResponse.to_string(resp)
    :gen_tcp.send(req, resp_string)
    Logger.info("Response sent: \n#{resp_string}")
    :gen_tcp.close(req)
  end

  defp responder do
    Application.get_env(:goldcrest_http_server, :responder)
  end

  def child_spec(init_args) do
    %{
      id: __MODULE__,
      start: {Task, :start_link, [fn -> apply(__MODULE__, :start, init_args) end]}
    }
  end
end
