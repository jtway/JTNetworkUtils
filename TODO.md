
## Notes

Some of the troubles with leveraging existing projects out there. Most objective-c and swift projects are derived from SimplePing. 

SimplePing was intended to be simple, in other words send, and did we get a reply, if so handle it. It was not designed to actually get latency information or act like ping.

Using Apple's opensource form of [BSD ping][1] or Unix Network Programming, although both of these assume you're using ICMP directly instead of UDP.

   [1]: http://www.opensource.apple.com/source/network_cmds/network_cmds-457/        "BSD ping"
   
Personally I've always found so of the async i/o patterns a bit troubling. However, that's a conversation for another day, lets just say there are times where send, then wait for a response are not only useful, but invaluable for avoiding cluttered up, overly complex, code.

In the case of ping, since you want to send on a set interval, and receive when ever you receive, async read is good, but sending is done on an interval. In bsd ping this is done using alarms to act as a heart beat which allows a some what async send (think std:async, or using dispatch_after on a global queue), while maintaining the sequential sends of the ping packets.

Using this approach allows the main loop to simply wait on select and if it times out mark a packet as such. If the packet arrives after this time, it is ignored.

	This brings up another point, unlike SimplePing and a lot of these objc and swift pings, you need to track the sequence number.
	
### What's my point?

So, ping and ping6, have multiple options for waiting on individual pings and to stop regardless of how many pings have been sent or received. We'll need that here.

What else, using a dispatch\_source_t with a read type means it controls all this for you, however how do you know when an individual ping has timed out? Do we use another timer?


Well this makes me realize I'm not even sure how ping knows which ping timed out... And this is where I've left off...


