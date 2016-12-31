PSRemotely module when imported creates a global scope variable which stores the following:
- NodeMap *Collection of each node's status*
- Session Hashtable *Hashtable which maintains PSSession for the nodes along with the credentials used (if any)*
- RemotelyNodePath *The local path location to be used on the nodes by Remotely (read from Remotely.json)*
- ModulesRequired *Array of ModulesRequired (read from Remotely.json)*