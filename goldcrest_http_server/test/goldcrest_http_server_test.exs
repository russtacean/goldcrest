defmodule GoldcrestHTTPServerTest do
  use ExUnit.Case, async: false

  @port 4041

  setup_all do
    Finch.start_link(name: Goldcrest.Finch)
    :ok
  end

  describe "start/2" do
    setup tags do
      responder = tags[:responder]
      old_responder = Application.get_env(:goldcrest_http_server, :responder)
      Application.put_env(:goldcrest_http_server, :responder, responder)
      on_exit(fn -> Application.put_env(:goldcrest_http_server, :responder, old_responder) end)
      :ok
    end

    @tag responder: nil
    test "Raises when responder not configured" do
      err_str = "No `responder` configured for `goldcrest_http_server"
      assert_raise(RuntimeError, err_str, fn -> Goldcrest.HTTPServer.start(@port) end)
    end

    @tag responder: Goldcrest.TestResponder
    test "Starts a server when a responder is configured" do
      Task.start_link(fn -> Goldcrest.HTTPServer.start(@port) end)

      {:ok, response} =
        :get
        |> Finch.build("http://localhost:#{@port}/hello")
        |> Finch.request(Goldcrest.Finch)

      assert response.body == "Hello World!"
      assert response.status == 200
      assert {"content-type", "text/html"} in response.headers

      {:ok, response} =
        :get
        |> Finch.build("http://localhost:#{@port}/bad")
        |> Finch.request(Goldcrest.Finch)

      assert response.body == "Not Found"
      assert response.status == 404
      assert {"content-type", "text/html"} in response.headers
    end
  end
end
