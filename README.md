BT Robocode Battle 2012 robot uploader
====

Based on [sinatra-bootstrap](https://github.com/pokle/sinatra-bootstrap).

Instructions
===

    git clone https://github.com/kerryb/robot-uploader.git

    cd robot-uploader
    bundle install
    ln -s /robocode-dir/robots ./robots

Then run using

    ruby app.rb

To run in development mode (ie pick up changed code without restarting):

    shotgun app.rb

Then open [http://localhost:9393/](http://localhost:9393/)

To record scores for a round, save the CSV output from Robocode to the `scores`
directory. The filenames don't really matter, but will be read in directory
listing order, so it's probably easiest to just use `1.csv` for round one etc.
