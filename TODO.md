*** This is by no means comprehensive ***

Honor ping count, timeout, ttl?
Finish IPv6 support

Either wrap with ping queue and add in initialize with a SocketAddress (would allow us to have two sockets for reads/writes)
Alternatively, could switch to ping taking hostname or IP, manage it's own serial dispatch queue, and keep a list of completion handlers. Trouble here is do we automatically create sockets for IPv4 and IPv6? Probably just initialize to -1 and create the sockets lazily.

