Put.io sync
===========

A small script that fetches all the files from your [Put.io](http://put.io) account into a
local folder.

Install
-------

* Install ruby 1.9.3+
* Create an "application" here and note down the TOKEN: https://put.io/v2/oauth2/applications
* `ruby putio-sync.rb ./where/to/put/the/files YOUR_TOKEN`

^--- or put is in your crontab:

`*/15 * * * * ruby $HOME/putio-sync.rb /mnt/inbox/putio YOUR_TOKEN`
