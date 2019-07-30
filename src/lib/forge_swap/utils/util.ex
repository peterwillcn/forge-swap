defmodule ForgeSwap.Utils.Util do
  require Logger

  alias ForgeSwapWeb.Router.Helpers
  alias ForgeSwapWeb.Endpoint

  def str_to_bin(str) do
    case Base.decode16(str, case: :mixed) do
      {:ok, bin} ->
        bin

      _ ->
        case Multibase.decode(str) do
          {:ok, bin} -> bin
          _ -> Base.url_decode64!(str, padding: false)
        end
    end
  end

  def str_to_int(nil), do: nil
  def str_to_int(""), do: nil

  def str_to_int(str) do
    str |> String.trim() |> String.to_integer()
  end

  def gen_qr_code(url) when is_binary(url), do: url |> EQRCode.encode() |> EQRCode.svg()

  # Generates the QR code by scanning which a user can start the swap process.
  def gen_qr_code("not_started", swap_id),
    do: Endpoint |> Helpers.start_swap_url(:start, swap_id) |> padding() |> gen_qr_code()

  # Generates the QR code by scanning which a user can continue to retrieve the swap set up by application.
  def gen_qr_code("both_set_up", swap_id),
    do: Endpoint |> Helpers.retrieve_swap_url(:retrieve, swap_id) |> padding() |> gen_qr_code()

  def gen_qr_code(_, _), do: ""

  def padding(url),
    do: "https://abtwallet.io/i/?action=requestAuth&url=#{URI.encode_www_form(url)}"
end