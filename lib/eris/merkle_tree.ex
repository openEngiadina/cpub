defmodule ERIS.MerkleTree do
  @moduledoc """
  Lower-level encoding helpers for ERIS
  """

  alias ERIS.{BlockStorage, Crypto}

  # Return a stream of blocks
  def chunk_into_blocks(data, block_size \\ 4096) do
    Stream.resource(
      fn -> data end,
      fn data ->
        case data do
          <<>> ->
            {:halt, <<>>}

          <<head::binary-size(block_size), rest::binary>> ->
            {[head], rest}

          _ ->
            {[data], <<>>}
        end
      end,
      fn _ -> :ok end
    )
  end

  defp init_state(block_storage, verification_key),
    do: %{
      levels: %{},
      level_count: %{},
      block_storage: block_storage,
      verification_key: verification_key
    }

  defp get_level(state, level), do: Access.get(state.levels, level, [])

  defp get_level_count(state, level), do: Access.get(state.level_count, level, 0)

  defp add_ref_to_level(state, level, ref) do
    new_levels =
      state.levels
      |> Map.put(level, get_level(state, level) ++ [ref])

    new_count =
      state.level_count
      |> Map.put(level, get_level_count(state, level) + 1)

    %{state | levels: new_levels, level_count: new_count}
  end

  defp clear_level(state, level) do
    new_levels =
      state.levels
      |> Map.delete(level)

    %{state | levels: new_levels}
  end

  defp base_encode(n, encoded) do
    if n > 0 do
      r = Integer.mod(n, 128)
      base_encode(((n - r) / 128) |> round(), encoded ++ [r])
    else
      encoded
      |> Enum.reverse()
    end
  end

  defp compute_node_nonce(level, count) do
    base_encoded = base_encode(count, [])

    (List.duplicate(0, 12 - level + 1 - length(base_encoded)) ++
       base_encoded ++
       List.duplicate(255, level - 1))
    |> :binary.list_to_bin()
  end

  defp create_node(refs) do
    (refs ++ List.duplicate(<<0::256>>, 128 - length(refs)))
    |> Enum.join()
  end

  defp force_collect(state, level) do
    # position of node to be created
    node_level = level + 1
    node_count = get_level_count(state, node_level)

    # compute nonce from node position
    nonce = compute_node_nonce(node_level, node_count)

    node =
      get_level(state, level)
      |> create_node
      |> Crypto.xor(key: state.verification_key, nonce: nonce)

    with {:ok, node_ref, bs} <- BlockStorage.put(state.block_storage, node) do
      %{state | block_storage: bs}
      |> add_ref_to_level(node_level, node_ref)
      |> clear_level(level)
    end
  end

  defp collect(state, level) do
    if state.level_count[level] >= 128 do
      state
      |> force_collect(level)
      |> collect(level + 1)
    else
      state
    end
  end

  defp finalize(state, level) do
    top_level = state.levels |> Map.keys() |> Enum.max()
    current_level = get_level(state, level)

    cond do
      level == top_level and length(current_level) == 1 ->
        {level, hd(current_level), state.block_storage}

      not Enum.empty?(current_level) ->
        state
        |> force_collect(level)
        |> finalize(level + 1)

      Enum.empty?(current_level) ->
        state
        |> finalize(level + 1)
    end
  end

  def encode(data, verification_key: verification_key, block_storage: block_storage) do
    data
    |> chunk_into_blocks()
    |> Enum.reduce(init_state(block_storage, verification_key), fn block, state ->
      with {:ok, ref, bs} <- BlockStorage.put(state.block_storage, block) do
        %{state | block_storage: bs}
        |> add_ref_to_level(0, ref)
        |> collect(0)
      end
    end)
    |> finalize(0)
  end

  defp is_null_ref(ref), do: <<0::256>> == ref

  def decode(ref, level, count,
        verification_key: verification_key,
        block_storage: block_storage
      ) do
    with {:ok, block} <- BlockStorage.get(block_storage, ref) do
      if level == 0 do
        [block]
      else
        Crypto.xor(block, key: verification_key, nonce: compute_node_nonce(level, count))
        |> chunk_into_blocks(32)
        |> Stream.take_while(fn ref -> not is_null_ref(ref) end)
        |> Stream.zip(0..127)
        |> Stream.flat_map(fn {ref, k} ->
          decode(ref, 1 - level, 128 * count + k,
            verification_key: verification_key,
            block_storage: block_storage
          )
        end)
      end
    end
  end
end
