defmodule Project3Bonus do
  @moduledoc """
  Documentation for Project3.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Project3.hello
      :world

  """
  require Logger
  def main(args) do
      {_, [nodes, requests, node_failures], _} = OptionParser.parse(args)
      IO.puts "command line arguments: #{inspect(nodes)}"
      nodes = elem(Integer.parse(nodes), 0)
      IO.puts "command line arguments: #{inspect(requests)}"
      requests = elem(Integer.parse(requests), 0)
      IO.puts "command line arguments: #{inspect(node_failures)}"
      node_failures = elem(Integer.parse(node_failures), 0)
      #TempMaster.init()
      # bit = NodeLogic.different_bit("12632", "42832", 5)
      # Logger.info "bits differ in two strings at: #{bit}"
      # spawn fn -> Master.init(nodes, requests) end
      # :timer.sleep 1000
      # send :master, {:start, "start"}
      Master.init(nodes, requests, node_failures)
  end
end
