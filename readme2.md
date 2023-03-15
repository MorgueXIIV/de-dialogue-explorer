# WINDOWS GUIDE TO FAYDE

1. Download the file Morgue gives you. Step one, easy, right?

2. This is a *zipped*, or *compressed* file, which means you can't open it until you *unzip* it. To unzip the file, you can do one of two things:
    - Right-click on the file so that the right-click menu pops up, then click `Extract all...`.
    - At the top of the file menu while the file is selected, you might see a tab that says `Compressed Folder Tools` - click on it, then click `Extract All`. It should auto-create a new extracted (in other words, normal) folder. ![image of the file header normally](https://i.postimg.cc/PrrP1pLp/image.png) ![image of the file header after clicking Compressed Folder Tools](https://i.postimg.cc/NMBgYSm9/image.png)

3. Ok, now you have the FAYDE folder open...what next? What's this gem thing?  These `.db` and `.rb` files? 

    Well, see, you can't actually *use* FAYDE without installing Ruby - the programming language that FAYDE was built in -  
    
    Wait wait, don't go! *You* don't have to program, I promise. Morgue has already done all that work! You just need the tools that will *build* and *run* FAYDE.

    You'll find the tools, i.e. the Ruby Devkit, here - https://rubyinstaller.org/downloads/. As you can see on the page, the recommended one for newbies (which means you, since again, *you're* not programming!) is `Ruby+Devkit 2.7.2-1 (x64)`. So just click the link on the left side for that one, and let it download.

4. Click the downloaded `rubyinstaller-devkit-2.7.2-1-x64.exe` file to run it - it will pop up an installer that will walk you through installation of Ruby Devkit (make sure you choose to install MSYS too, this is the default). Don't change any settings, just agree to the license and click next until it's all finished (it will let you know!)

    A command line will pop up after you've clicked `Finish` - that's the black screen with the white hacker text. Press `Enter` on your keyboard each time it prompts you to type something. The command line will abruptly close. This will install MSYS.
    
    But we're not done, because doing that just installed Ruby - remember what I said about building FAYDE before you can run it?

5. Open up a new command line (and pretend you're a hacker!) There's a long way to do this but here's the short way: Type in `cmd` in the top bar where the folder name is, then press `Enter`.

    ![image of 'cmd' being typed into the bar](https://i.postimg.cc/wMKD6hgb/image.png)

6. Into the command line, type `gem install bundler` and press `Enter`. Shouldn't take more than a minute.

7. Type 'bundler install' and press `Enter`. This will take a bit longer!

8. Finally, type `ruby guidealoguebrowser.rb` and press `Enter` once more. The app will pop up once it's done!

    *Note: Don't close the command line once you have the app running, it'll shut down the app!*
    
    Whenever you close both, you'll have to go through the command line and type the `ruby guidealoguebrowser.rb` command again. (You may be able to just double-click this file if .rb files are set to open with Ruby already!)

9. The app will be on the `Display Options` tab when it first opens up. Click `Load Database`. If the file explorer that pops up isn't already in FAYDE's folder, navigate back to that folder and double-click `discobase9-4-2020-6-06-25-AM.db` (Or an older or newer one if you have those and want a particular version). Then click `Save Configs` so you don't have to do that every time you open FAYDE.

## Re-installation

If a new version comes out, you will **usually** only need to replace the `guidealoguebrowser.rb` in the folder, and open it as normal. 

