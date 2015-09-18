--with the release of the official server management tool, arkontrol is effectively a dead project.

# arkontrol-arkonboard

Server setup for arkontrol


Just like the game itself, we are deep into Alpha phase testing, but far from finished.

INSTRUCTIONS:
  1. Obtain a Cloud or Dedicated server with at least 3GB of RAM, and a fresh installation of Ubuntu 14.04 LTS
  2. Login to the system
  3. sudo wget http://cdn.arkontrol.com/arkontrol
  4. sudo sh arkontrol


That's it! It will take about an hour to install everything, based on your network speed and how busy Steam's servers are at the time.

Sometimes, the Steam installer will break part way through. The best thing to do if that fails is to just run the script again
  sudo sh arkontrol
  
However, if the web panel (arkontrol-php) is already installed, you can use this to attempt to reinstall the ARK Dedicated Server. Either way, it will resume a partially completed download. We've had instances where everything worked in one shot, and some where it took more than 10 tries to complete the download.
