# PSRemotely global scope variable

PSRemotely module when imported creates a global scope variable which stores the following:

1. NodeMap *Collection of each node's status*
2. Session Hashtable *Hashtable which maintains PSSession for the nodes along with the credentials used (if any)*
3. RemotelyNodePath *The local path location to be used on the nodes by PSRemotely (read from Remotely.json)*
4. ModulesRequired *Array of ModulesRequired (read from Remotely.json)*

Each time you invoke PSRemotely to run validation tests targeted to the remote nodes, the required information
is updated in the PSRemotely global variable.

So if you want to remove all the information stored in this variable in one go, then importing the module again
with *-Force* switch passed to *Import-Module* will work.