# Project3

READ ME file for Distributed Operating Systems - Project 3, Due Date: 23rd October,2017

Group members:

Team 3
1. Anmol Khanna, UFID:65140549, anmolkhanna93@ufl.edu,
2. Akshay Singh Jetawat, UFID:22163183, akshayt80@ufl.edu,


# Execution Steps

compile: mix clean, mix escript.build

running: ./project3 numNodes numRequest

# What is working 
We have implemented the Pastry protocol as described in the paper as given in the project specifications. The route and the join mechanisms are also working.

As of now our join algorithm is little slow O(n^2). So, it takes time join operation to finish when the number of nodes is more than 10000.

# Largest network managed

We tested for different combinations of number of nodes and number of requests. Below are some of the readings for the same:

|Nodes |Requests	|Avg Hops|
|------|--------- |-------|
|10	   |10        |1.06 	 |
|100	  |10  	     |2.25	  |
|100	  |100 	     |2.28   |
|500	  |10  	     |3.08   |
|500   |100       |3.11   |
|1000	 |10  	     |3.51   |
|1000  |100       |3.53   |
|2000  |10        |3.86   |
|10000 |2     |4.74   |
