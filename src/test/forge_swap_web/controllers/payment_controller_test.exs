defmodule ForgeSwapWeb.PaymentControllerTest do
  use ForgeSwapWeb.ConnCase

  alias ForgeAbi.Util.BigInt
  alias ForgeAbi.{RetrieveSwapTx, RevokeSwapTx, SetupSwapTx}
  alias ForgeSwapWebTest.Util
  alias ForgeSwap.Schema.Swap
  alias ForgeSwap.Repo

  @sha3 %Mcrypto.Hasher.Sha3{}
  @user %{
    address: "z1SWvGbnCiJf5MpWnV8qoYQWrYnK2BdtpaQ",
    pk:
      <<248, 202, 174, 37, 243, 223, 249, 206, 99, 222, 173, 12, 97, 245, 149, 210, 123, 29, 16,
        101, 60, 167, 206, 217, 141, 96, 75, 48, 20, 159, 173, 66>>,
    sk:
      <<130, 122, 74, 55, 242, 33, 15, 235, 96, 163, 197, 239, 122, 63, 172, 44, 67, 33, 94, 158,
        32, 98, 206, 163, 30, 151, 42, 71, 169, 214, 132, 178, 248, 202, 174, 37, 243, 223, 249,
        206, 99, 222, 173, 12, 97, 245, 149, 210, 123, 29, 16, 101, 60, 167, 206, 217, 141, 96,
        75, 48, 20, 159, 173, 66>>
  }

  @delegator %{
    address: "z1fZwLq7gAcA7iw6RJ3SBKCZQUhF3ELn4pG",
    pk:
      <<19, 70, 210, 217, 68, 170, 215, 252, 170, 93, 193, 77, 250, 50, 92, 194, 62, 47, 198, 162,
        205, 249, 217, 134, 197, 34, 139, 182, 50, 234, 135, 88>>,
    sk:
      <<216, 5, 29, 23, 112, 173, 251, 92, 133, 123, 214, 171, 117, 204, 62, 119, 69, 192, 151,
        88, 249, 16, 56, 231, 70, 225, 251, 142, 150, 92, 188, 125, 19, 70, 210, 217, 68, 170,
        215, 252, 170, 93, 193, 77, 250, 50, 92, 194, 62, 47, 198, 162, 205, 249, 217, 134, 197,
        34, 139, 182, 50, 234, 135, 88>>
  }

  @owner %{
    address: "z1ewYeWM7cLamiB6qy6mDHnzw1U5wEZCoj7",
    pk:
      <<117, 203, 141, 163, 125, 31, 190, 56, 26, 215, 25, 10, 206, 28, 135, 228, 209, 49, 42,
        104, 155, 38, 5, 244, 194, 122, 44, 158, 28, 230, 60, 197>>,
    sk:
      <<180, 193, 254, 213, 9, 13, 214, 69, 24, 194, 14, 175, 95, 22, 54, 203, 76, 42, 104, 69,
        106, 148, 81, 97, 25, 38, 53, 239, 184, 60, 103, 82, 117, 203, 141, 163, 125, 31, 190, 56,
        26, 215, 25, 10, 206, 28, 135, 228, 209, 49, 42, 104, 155, 38, 5, 244, 194, 122, 44, 158,
        28, 230, 60, 197>>
  }

  @offer_token 111_111_111_111_111
  @demand_token 222_222_222_222_222

  @tag :integration
  test "Start and retrieve swap, all good", %{conn: conn} do
    # Executes the common steps to set up swap.
    {id, _, hashkey, callback} = both_set_up_swap(conn, 28800, 57600)

    # Step 5: wallet poll the swap set up by application by calling the callback

    %{"appPk" => pk, "authInfo" => auth_info} =
      conn
      |> post(callback, Util.gen_signed_request(@user, %{}))
      |> json_response(200)

    auth_body = Util.get_auth_body(auth_info)
    Util.assert_common_auth_info(pk, auth_body)
    %{"response" => %{"swapAddress" => swap_address}} = auth_body
    assert String.length(swap_address) > 0

    # Step 6: Wallet retrieve the swap
    tx = RetrieveSwapTx.new(address: swap_address, hashkey: hashkey)
    hash = ForgeSdk.retrieve_swap(tx, wallet: @user, send: :commit, conn: "app_chain")
    assert is_binary(hash)

    Process.sleep(10 * 1000)
    swap = Swap.get(id)
    assert swap.status == "both_retrieved"
    assert String.length(swap.retrieve_hash) > 0
  end

  @tag :integration
  test "Start by delegator and retrieve swap, all good", %{conn: conn} do
    # First, delegates the set up swap tx to delegator.
    itx =
      ForgeAbi.DelegateTx.new(
        to: @delegator.address,
        ops: [ForgeAbi.DelegateOp.new(type_url: "fg:t:setup_swap", rules: [])]
      )

    hash = ForgeSdk.delegate(itx, wallet: @user)
    assert is_binary(hash) == true

    # Executes the common steps to set up swap.
    {id, _, hashkey, callback} = both_set_up_swap(conn, 28800, 57600, @delegator)

    # Step 5: wallet poll the swap set up by application by calling the callback

    %{"appPk" => pk, "authInfo" => auth_info} =
      conn
      |> post(callback, Util.gen_signed_request(@user, %{}))
      |> json_response(200)

    auth_body = Util.get_auth_body(auth_info)
    Util.assert_common_auth_info(pk, auth_body)
    %{"response" => %{"swapAddress" => swap_address}} = auth_body
    assert String.length(swap_address) > 0

    # Step 6: Wallet retrieve the swap
    tx = RetrieveSwapTx.new(address: swap_address, hashkey: hashkey)
    hash = ForgeSdk.retrieve_swap(tx, wallet: @user, send: :commit, conn: "app_chain")
    assert is_binary(hash)

    Process.sleep(10 * 1000)
    swap = Swap.get(id)
    assert swap.status == "both_retrieved"
    assert String.length(swap.retrieve_hash) > 0
  end

  @tag :integration
  test "Start and revoke swap, all good", %{conn: conn} do
    {id, swap_address, _, _} = both_set_up_swap(conn, 2, 3)

    # Step 5, Wallet Revoke the swap.
    tx = RevokeSwapTx.new(address: swap_address)
    hash = ForgeSdk.revoke_swap(tx, wallet: @user, send: :commit, conn: "asset_chain")
    assert is_binary(hash)

    Process.sleep(10 * 1000)
    swap = Swap.get(id)
    assert swap.status == "both_revoked"
    assert String.length(swap.revoke_hash) > 0
  end

  defp both_set_up_swap(conn, offer_locktime, demand_locktime, delegator \\ nil) do
    # Create a Swap 
    {:ok, %{id: id}} =
      %{
        "userDid" => @user.address,
        "offerToken" => @offer_token,
        "demandToken" => @demand_token,
        "offerLocktime" => offer_locktime,
        "demandLocktime" => demand_locktime
      }
      |> Util.create_swap()
      |> Repo.insert()

    # Step 1, Wallet scans the QR code
    %{"appPk" => pk, "authInfo" => auth_info} =
      conn
      |> get(Routes.payment_path(conn, :start, id))
      |> json_response(200)

    auth_body = Util.get_auth_body(auth_info)
    Util.assert_common_auth_info(pk, auth_body)
    assert auth_body["url"] === Routes.payment_url(@endpoint, :auth_principal, id)

    assert auth_body["requestedClaims"] == [
             %{
               "type" => "authPrincipal",
               "description" => "Please set the authentication principal to the specified DID.",
               "target" => "#{@user.address}",
               "meta" => nil
             }
           ]

    # Step 2, Wallet returns user did
    %{"appPk" => pk, "authInfo" => auth_info} =
      conn
      |> post(auth_body["url"], Util.gen_signed_request(@user, %{}))
      |> json_response(200)

    auth_body = Util.get_auth_body(auth_info)
    Util.assert_common_auth_info(pk, auth_body)
    assert auth_body["url"] === Routes.payment_url(@endpoint, :payment_return_swap, id)

    assert auth_body["requestedClaims"] == [
             %{
               "type" => "swap",
               "demandAssets" => [],
               "demandChain" => "asset_chain",
               "demandLocktime" => demand_locktime,
               "demandToken" => @demand_token,
               "offerAssets" => [],
               "offerToken" => @offer_token,
               "receiver" => @owner.address,
               "description" => "Please set up an atomic swap on the ABT asset chain.",
               "meta" => nil
             }
           ]

    # Step 3, Wallet sets up a swap on required chain.
    hashkey = :crypto.strong_rand_bytes(128)
    hashlock = Mcrypto.hash(@sha3, hashkey)
    current_block = ForgeSdk.get_chain_info("asset_chain").block_height

    tx =
      SetupSwapTx.new(
        value: BigInt.biguint(@demand_token),
        assets: [],
        receiver: @owner.address,
        locktime: current_block + demand_locktime + 5,
        hashlock: hashlock
      )

    hash =
      case delegator do
        nil ->
          ForgeSdk.setup_swap(tx, wallet: @user, send: :commit, conn: "asset_chain")

        _ ->
          ForgeSdk.setup_swap(tx,
            wallet: delegator,
            delegatee: @user.address,
            send: :commit,
            conn: "asset_chain"
          )
      end

    assert is_binary(hash)
    swap_address = ForgeSdk.Util.to_swap_address(hash)

    # Step 4: wallet return swap_address
    body =
      Util.gen_signed_request(@user, %{
        "requestedClaims" => [%{"type" => "swap", "address" => swap_address}]
      })

    %{"appPk" => pk, "authInfo" => auth_info} =
      conn
      |> post(auth_body["url"], body)
      |> json_response(200)

    auth_body = Util.get_auth_body(auth_info)
    Util.assert_common_auth_info(pk, auth_body)
    %{"response" => %{"callback" => callback}} = auth_body

    Process.sleep(6 * 1000)

    swap = Swap.get(id)
    assert swap.user_did == @user.address
    assert swap.status == "both_set_up"
    assert swap.demand_swap == swap_address

    {id, swap_address, hashkey, callback}
  end
end
