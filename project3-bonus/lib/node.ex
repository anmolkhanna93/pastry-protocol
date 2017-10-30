defmodule PastryNode do
    require Logger
    def init(numNodes, numRequests, id, base, nodeIdSpace) do
        Logger.debug "Initializing node: Node_#{id}"
        larger_leafs = []
        smaller_leafs = []
        table = []
        numOfBack = 0

        table = for i <- 0..base-1 do
            [-1, -1, -1, -1]
        end

        listen(id, base, larger_leafs, smaller_leafs, table, numRequests, numNodes, nodeIdSpace, numOfBack)
    end
    # can be removed if we are using hash
    defp toBase4String(raw, base) do
        str = Integer.to_string(raw, 4)
        diff = base - String.length(str)
        # add padding of 0 in front
        if diff > 0 do
            str = String.pad_leading(str, base, "0")
        end
        str
    end
    def different_bit(nodeId1, nodeId2, base, bit, curr_pos) when (curr_pos == base) do
        # when first bit also doesn't match
        if bit < 0 do
            bit = 0
        else
            bit = bit + 1
        end
        bit
    end
    def different_bit(nodeId1, nodeId2, base, bit \\ -1, curr_pos \\ 0) do
        char1 = String.at(nodeId1, curr_pos)
        char2 = String.at(nodeId2, curr_pos)
        if (char1 == char2) and (bit == curr_pos-1) do
            bit = curr_pos
        end
        curr_pos = curr_pos + 1
        different_bit(nodeId1, nodeId2, base, bit, curr_pos)
    end
    # add nodes to leaf sets
    defp add_nodes(all, larger_leafs, smaller_leafs, table, id, base, current, size) when current >= size do
        {larger_leafs, smaller_leafs, table}
    end
    defp add_nodes(all, larger_leafs, smaller_leafs, table, id, base, current \\ -1, size \\ 0) do
        if size == 0 do
            size = length(all)
        end
        if current == -1 do
            current = 0
        end
        i = Enum.at(all, current)
        current = current + 1

        {larger_leafs, smaller_leafs, table} = add_node(i, larger_leafs, smaller_leafs, table, id, base)

        add_nodes(all, larger_leafs, smaller_leafs, table, id, base, current, size)
    end
    defp add_node(newNode, larger_leafs, smaller_leafs, table, id, base) do
        {larger_leafs, smaller_leafs} = update_leaf(newNode, id, larger_leafs, smaller_leafs)
        samePrefix = different_bit(toBase4String(id, base), toBase4String(newNode, base), base)
        table_row = Enum.at(table, samePrefix)
        index = toBase4String(newNode, base) |> String.at(samePrefix) |> Integer.parse |> elem(0)
        element_in_row = Enum.at(table_row, index)
        if element_in_row == -1 do
            updated_row = List.replace_at(table_row, index, newNode)
            table = List.replace_at(table, samePrefix, updated_row)
        end
        {larger_leafs, smaller_leafs, table}
    end
    defp update_leaf(newNode, id, larger_leafs, smaller_leafs) do
        if newNode > id and not(Enum.member?(larger_leafs, newNode)) do
            if length(larger_leafs) < 4 do
                larger_leafs = larger_leafs ++ [newNode]
            else
                if newNode < Enum.max(larger_leafs) do
                    larger_leafs = larger_leafs -- [Enum.max(larger_leafs)]
                    larger_leafs = larger_leafs ++ [newNode]
                end
            end
        else
            if newNode < id and not(Enum.member?(smaller_leafs, newNode)) do
                if length(smaller_leafs) < 4 do
                    smaller_leafs = smaller_leafs ++ [newNode]
                else
                    if newNode > Enum.min(smaller_leafs) do
                        smaller_leafs = smaller_leafs -- [Enum.min(smaller_leafs)]
                        smaller_leafs = smaller_leafs ++ [newNode]
                    end
                end
            end
        end
        {larger_leafs, smaller_leafs}
    end
    defp update_leafs(newNodes, id, larger_leafs, smaller_leafs, current, size) when current >= size do
        Logger.debug "updated_leaf: large: #{inspect(larger_leafs)} small: #{inspect(smaller_leafs)}"
        {larger_leafs, smaller_leafs}
    end
    defp update_leafs(newNodes, id, larger_leafs, smaller_leafs, current \\ -1, size \\ 0) do
        if size == 0 do
            size = length(newNodes)
        end
        if current == -1 do
            current = 0
        end

        i = Enum.at(newNodes, current)
        current = current + 1

        {larger_leafs, smaller_leafs} = update_leaf(i, id, larger_leafs, smaller_leafs)

        update_leafs(newNodes, id, larger_leafs, smaller_leafs, current, size)
    end
    defp listen(id, base, larger_leafs, smaller_leafs, table, numRequests, numNodes, nodeIdSpace, numOfBack) do
        receive do
            {:startRouting, value} ->
                Logger.debug "Node_#{id} starting routing"
                spawn fn -> start_async_requests(numRequests, nodeIdSpace, id) end
            {:initialJoin, {from, group}} -> groupOne = group -- [id]
                Logger.debug "Node_#{id} groupOne: #{inspect(groupOne)}"
                {larger_leafs, smaller_leafs, table} = add_nodes(groupOne, larger_leafs, smaller_leafs, table, id, base)
                table = for i <- 0..base-1 do
                    table_row = Enum.at(table, i)
                    index = toBase4String(id, base) |> String.at(i) |> Integer.parse |> elem(0)
                    List.replace_at(table_row, index, id)
                end
                Logger.debug "Node_#{id} larger_leafs: #{inspect(larger_leafs)} smaller_leafs: #{inspect(smaller_leafs)} table: #{inspect(table)}"
                send from, {:finishedJoining, "finished joining"}
            {:route, {from, to, hops}} ->
                Logger.debug "Node_#{id} from: #{from} to: #{to} hops: #{hops}"
                if id == to do
                    send :master, {:routeFinish, {from, to, hops + 1}}
                else
                    samePrefix = different_bit(toBase4String(id, base), toBase4String(to, base), base)
                    table_row = Enum.at(table, samePrefix)
                    Logger.debug "Node_#{id} sameprefix: #{samePrefix} table row: #{inspect(table_row)}"
                    index = toBase4String(to, base) |> String.at(samePrefix) |> Integer.parse |> elem(0)
                    cond do
                       (length(smaller_leafs) > 0 and to >= Enum.min(smaller_leafs) and to < id) or (length(larger_leafs) > 0 and to <= Enum.max(larger_leafs) and to > id) ->
                            diff = nodeIdSpace + 10
                            nearest = -1
                            # in smaller leafs
                            if to < id do
                                {nearest, diff} = get_nearest(to, smaller_leafs, nearest, diff)
                            # in larger leafs
                            else
                                {nearest, diff} = get_nearest(to, larger_leafs, nearest, diff)
                            end

                            if abs(to - id) > diff do
                                send :"Node_#{nearest}", {:route, {from, to, hops + 1}}
                            else
                                Logger.debug "Node_#{id}, route finished"
                                send :master, {:routeFinish, {from, to, hops + 1}}
                            end
                    length(smaller_leafs) < 4 and length(smaller_leafs) > 0 and to < Enum.min(smaller_leafs) ->
                        send :"Node_#{Enum.min(smaller_leafs)}", {:route, {from, to, hops + 1}}
                    length(larger_leafs) < 4 and length(larger_leafs) > 0 and to > Enum.max(larger_leafs) ->
                        send :"Node_#{Enum.max(larger_leafs)}", {:route, {from, to, hops + 1}}
                    (length(smaller_leafs) == 0 and to < id) or (length(larger_leafs) == 0 and to > id) ->
                        # current node is closest
                        send :master, {:routeFinish, {from, to, hops + 1}}
                    Enum.at(table_row, index) != -1 ->
                        send :"Node_#{Enum.at(table_row, index)}", {:route, {from, to, hops + 1}}
                    to > id ->
                        send :"Node_#{Enum.max(larger_leafs)}", {:route, {from, to, hops + 1}}
                        send :master, {:notInBoth, "not in both"}
                    to < id ->
                        send :"Node_#{Enum.min(smaller_leafs)}", {:route, {from, to, hops + 1}}
                        send :master, {:notInBoth, "not in both"}
                    true -> Logger.info "Node_#{id} Impossible!!! from: #{from} to: #{to}"
                    end
                end
            {:terminate, registry} -> new_registry = registry -- [id]
                for i <- new_registry do
                    send :"#{i}", {:removeNode, id}
                end
                Process.sleep(1000)
            {:removeNode, nodeId} -> 
                if nodeId != id do
                    if nodeId > id and Enum.member?(larger_leafs, nodeId) do
                        larger_leafs = larger_leafs -- [nodeId]
                        if length(larger_leafs) > 0 do
                            send :"Node_#{Enum.max(larger_leafs)}", {:getLeafExcept, self(), nodeId}
                        else
                            larger_leafs = []
                        end
                    end
                    if nodeId < id and Enum.member?(smaller_leafs, nodeId) do
                        smaller_leafs = smaller_leafs -- [nodeId]
                        if length(smaller_leafs) > 0 do
                            send :"Node_#{Enum.min(smaller_leafs)}", {:getLeafExcept, self(), nodeId}
                        else
                            smaller_leafs = []
                        end
                    end

                    samePrefix = different_bit(toBase4String(id, base), toBase4String(nodeId, base), base)
                    table_row = Enum.at(table, samePrefix)
                    integer = toBase4String(nodeId, base) |> String.at(samePrefix)
                    Logger.debug "number to be parsed: #{integer}"
                    index = toBase4String(nodeId, base) |> String.at(samePrefix) |> Integer.parse |> elem(0)
                    element_in_row = Enum.at(table_row, index)

                    if element_in_row == nodeId do
                        updated_row = List.replace_at(table_row, index, -1)
                        table = List.replace_at(table, samePrefix, updated_row)
                        for i <- 0..3 do
                            table_row = Enum.at(table, samePrefix)
                            element = Enum.at(table_row, i)
                            if element != nodeId and element != id and element != -1 do
                                send :"Node_#{element}", {:getTableElement, self(), samePrefix, index}
                            end
                        end
                    end
                end
            {:getLeafExcept, from, nodeId} -> leafs = (larger_leafs ++ smaller_leafs) -- [nodeId]
                send from, {:adjustLeaf, leafs, nodeId}
            {:adjustLeaf, newLeafs, removedNodeId} ->
                {larger_leafs, smaller_leafs} = update_leafs(newLeafs, id, larger_leafs, smaller_leafs)
            {:getTableElement, from, row, col} ->
                table_row = Enum.at(table, row)
                element = Enum.at(table_row, col)
                if element != -1 do
                    send from, {:adjustTable, row, col, element}
                end
            {:adjustTable, row, col, newValue} -> 
                table_row = Enum.at(table, row)
                element = Enum.at(table_row, col)
                if element == -1 do
                    updated_row = List.replace_at(table_row, col, newValue)
                    table = List.replace_at(table, row, updated_row)
                end
        end
        listen(id, base, larger_leafs, smaller_leafs, table, numRequests, numNodes, nodeIdSpace, numOfBack)
    end
    defp get_nearest(to, leafs, nearest, diff) when leafs == [] do
        {nearest, diff}
    end
    defp get_nearest(to, leafs, nearest, diff) do
        [current | remaining_leafs] = leafs
        Logger.debug "nearest: #{current} remaining_leafs: #{inspect(remaining_leafs)}, to: #{to}"
        if abs(to - current) < diff do
            nearest = current
            diff = abs(to - current)
        end
        get_nearest(to, remaining_leafs, nearest, diff)
    end
    defp start_async_requests(numRequests, nodeIdSpace, id) do
        for i <- 0..numRequests-1 do
            # sending request every second to self
            :timer.sleep 1000
            to = :rand.uniform(nodeIdSpace - 1 )
            Logger.debug "Node_#{id} sending request: from: #{id} to: #{to}"
            send :"Node_#{id}", {:route, {id, to, -1}}
        end
    end
end
