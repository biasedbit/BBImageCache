BBImageCache With GCD IO
------------------------

An example of an image cache involves around dispatch_io (new from iOS 5 and upward).

This example is orignated from [http://biasedbit.com/filesystem-vs-coredata-image-cache](http://biasedbit.com/filesystem-vs-coredata-image-cache).
 Please make sure you read it first before playing.

The point of having dispatch_io handle file operation is to increase throughput for io performance gain. This example, unfortunately, fails to do so, and only demonstates how to deploy 'dispatch_io_write' function. 

Further, the goal of original example was to measure two cache machanisms as accurately as possible so that all the read/write operations were done in main thread synchronously. The async nature of dispatch_io hinders accurate measurement so that you would only see a measurement of activities done in main thread. 

In addition, no error handling is performed at the end of writing opertaion so take  measurements with utmost caution.

<h2><i>Tested on iPad 2 with iOS 5.1.1</i></h2>

###CoreData Cache

<pre><code>Testing BBCoreDataImageCache cache...

Execution times:
Store:		203.86ms
Sync:		102.28ms
Load:		799.31ms
Clear&Sync:	30.21ms
Store&Sync:	2024.05ms
Item count:	100

Execution times (w/ image building):
Store:		804.37ms
Sync:		18450.60ms
Load:		1168.99ms
Clear&Sync:	106.47ms
Store&Sync:	21711.31ms
Item count:	100</code></pre>

###Synchronous FileSystem Cache
<pre><code>Testing BBFilesystemImageCache cache...

Execution times:
Store:		14882.16ms
Sync:		5.24ms
Load:		70.28ms
Clear&Sync:	95.88ms
Store&Sync:	15334.06ms
Item count:	100

Execution times (w/ image building):
Store:		18598.41ms
Sync:		4.59ms
Load:		77.28ms
Clear&Sync:	96.16ms
Store&Sync:	19083.15ms
Item count:	100</code></pre>

###Asynchronous FS Cache w/ GCD_IO
<pre><code>Testing MTGCDFileIOCache filesystem cache...

Execution times:
Store:		1952.43ms
Sync:		1.33ms
Load:		99.19ms
Clear&Sync:	93.70ms
Store&Sync:	2026.35ms
Item count:	100

Execution times (w/ image building):
Store:		5523.24ms
Sync:		1.23ms
Load:		108.56ms
Clear&Sync:	95.97ms
Store&Sync:	5681.34ms
Item count:	100</code></pre>