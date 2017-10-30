defmodule Master do
    require Logger
    # This will be master node
    def init(numNodes, numRequests) do
        Process.register(self(), :master)
        base = round(:math.ceil(:math.log(numNodes) / :math.log(4)))
        nodeIdSpace = round(:math.pow(4, base))
        randomList = []
        registered_ids = []

        numHops = 0
        numJoined = 0
        numRouted = 0
        # not in leaf and routing table
        numNotInBoth = 0
        numRouteNotInBoth = 0

        i = -1

        Logger.debug "Number of Nodes: #{numNodes}"
        Logger.debug "Node ID Space: 0 ~ #{nodeIdSpace - 1}"
        Logger.debug "Number of requests per node: #{numRequests}"

        randomList = 0..nodeIdSpace-1 |> Enum.to_list

        # shuffle the random list
        randomList = Enum.shuffle randomList

        Logger.info "list of nodes: #{inspect(randomList)}"

        # adding nodes to group one
        registered_ids = for n <- 0..numNodes-1 do
            Enum.at(randomList, n)
        end

        # create nodes
        registry = for n <- 0..numNodes-1 do
            pid = spawn fn -> PastryNode.init(numNodes, numRequests, Enum.at(randomList, n), base, nodeIdSpace) end
            Logger.debug "Registering: Node_#{Enum.at(randomList, n)}"
            Process.register(pid, :"Node_#{Enum.at(randomList, n)}")
            :"Node_#{Enum.at(randomList, n)}"
        end

        # Sending initial join to all the nodes
        for i <- 0..numNodes-1 do
            id = Enum.at(registered_ids, i)
            send :"Node_#{id}", {:initialJoin, {self(), registered_ids}}
        end
        listen(randomList, numNodes, numRequests, numJoined, numNotInBoth, numRouted, numHops, numRouteNotInBoth, registry)

    end
    defp listen(randomList, numNodes, numRequests, numJoined, numNotInBoth, numRouted, numHops, numRouteNotInBoth,  registry) do
        receive do
            {:finishedJoining, value} -> numJoined = numJoined + 1
                if numJoined >= numNodes do
                    send self(), {:startRouting, "start routing"}
                end
            {:startRouting, value} -> Logger.info "Join is finished"
                Logger.info "Now starting with routing"
                for i <- registry do
                    Logger.debug "sending start route to : #{i}"
                    send :"#{i}", {:startRouting, "Start Routing"}
                end
            {:notInBoth, value} -> numNotInBoth = numNotInBoth + 1
            {:routeFinish, {from, to, hops}} -> numRouted = numRouted + 1
                numHops = numHops + hops
                if numRouted >= (numNodes * numRequests) do
                   avg = numHops / numRouted
                   Logger.info "Total routes: #{numRouted} Total hops: #{numHops}"
                   Logger.info "Average hops per route: #{avg}"
                   Logger.info "Closing simulation"
                   Process.exit(self(), :normal)
                end
            {:routeNotInBoth, value} -> numRouteNotInBoth = numRouteNotInBoth + 1
        end
        listen(randomList, numNodes, numRequests, numJoined, numNotInBoth, numRouted, numHops, numRouteNotInBoth,  registry)
    end
end