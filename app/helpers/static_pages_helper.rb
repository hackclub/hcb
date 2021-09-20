# frozen_string_literal: true

module StaticPagesHelper
  def card_to(name, path, options = {})
    return "" if options[:badge] == 0

    badge = options[:badge].to_i > 0 ? badge_for(options[:badge]) : ""
    link_to content_tag(:li,
                        [content_tag(:strong, name), badge].join.html_safe,
                        class: "card card--item card--hover relative overflow-visible line-height-3"),
                        path, method: options[:method]
  end

  def random_nickname
    if Rails.env.development?
      "Development Mode"
    else
      [
        "The hivemind known as Bank",
        "A cloud full of money",
        "Hack Club's pot of gold",
        "A sentient stack of dollars",
        "The Hack Club Federal Reserve",
        "money money money money money",
        "A money-crazed virus 🤑",
        "A cloud raining money",
        "A pile of money in the cloud",
        "Hack Club Smoothmunny",
        "Hack Club ezBUCKS",
        "Hack Club Money Bucket",
        "A mattress stuffed with 100 dollar bills", # this is the max length allowed for this header
        "Hack Club Dollaringos",
        "The Hack Foundation dba The Dolla Store",
        "Hack on.",
        "Open on weekends",
        "Open on holidays",
        "please don't hack",
        "HCB– Happily Celebrating Bees",
        "HCB– Hungry Computer Bison",
        "HCB– Huge Cellophane Boats",
        "HCB– Hydrofoils Chartered by Bandits",
        "The best thing since sliced bread",
        "Hack Club Bink",
        "Hack 👏 Club 👏 Bank 👏",
        "💻 ♣ 🏦",
        "aka Hack Bank",
        "aka Hank",
        "AKA dolla dolla billz",
        "AKA the nonprofit-atorium",
        "Open late",
        "From the makers of Hack Club",
        "Now in color!",
        "Filmed on location",
        "From the makers of Hack Club Bank",
        "Soon to be a major cryptocurrency!",
        "As seen on the internet",
        "👏 KEEP 👏 YOUR 👏 RECEIPTS 👏",
        "Money: collect it all!",
        "Help, I'm trapped in the internet!",
        "Most viewed site on this domain!",
        "Coming to a browser near you",
        "Hand-crafted by our resident byte-smiths",
        "B O N K",
        "#{rand 4..9}0% bug free!",
        "#{rand 1..4}0% less bugs!",
        "Ask your doctor if Hack Club Bank is right for you",
        'Now with "code"',
        "Closed source!",
        "Finally complete!",
        "Internet enabled!",
        "It's finally here!",
        "It's finished!",
        "Holds lots of cents",
        "It just makes cents",
        "By hackers for hackers",
        "Over 100 users!",
        "Over 20 accounts!",
        "Over $2,000,000 served!",
        "One of a kind!",
        "Reticulating splines...",
        "Educational!",
        "Don't use while driving",
        "Support local businesses!",
        "Take frequent breaks!",
        "Technically good!",
        "That's Numberwang!",
        "The bee's knees!",
        "Greater than the sum of its transactions!",
        "Greater than the sum of its donations!",
        "Greater than the sum of its invoices!",
        "Operating at a loss since 2018!",
        "The sum of its parts!",
        "Does anyone actually read this?",
        "Like and subscribe!",
        "Like that smash button!",
        "it protec, and also attac, but most importantly it pay fees back",
        "it secures the bag",
        "Protec but also attac",
        "As seen on bank.hackclub.com",
        "As seen on hackclub.com",
        "2 cool 4 scool",
        "Now running in production!",
        "put money in computer",
        "TODO: get that bread",
        "Coming soon to a screen near your face",
        "Coming soon to a screen near you",
        "As seen on the internet",
        "Operating at a loss so you don't have to",
        "Made by a non-profit for non-profits",
        "By hackers, for hackers",
        "It holds money!",
        "uwu",
        "owo",
        "ovo",
        "(◕‿◕✿)",
        "Red acting kinda sus",
        "An important part of this nutritional breakfast",
        "By people with money, for people with money",
        'Made using "money"',
        "Chosen #1 by dinosaurs everywhere",
        "Accountants HATE him",
        "Congratulations, you are the #{number_with_delimiter(10**rand(1..5))}th visitor!",
        "All the finance that's fit to print",
        "You've got this",
        "Don't forget to drink water!",
        "Putting the 'fun' in 'refund'",
        "Putting the 'fun' in 'fundraising'",
        "Putting the 'do' in 'donate'",
        "Donation nation",
        "To TCP, or UDP, that is the question",
        "Now with 0 off-by-one errors!",
        "Initial commit: get that bread",
        "git commit -m 'cash money'",
        "git commit -m 'get that bread'",
        "git commit --amend '$$$'",
        "git add ./cash/money",
        "Wireframed with real wire!",
        "Made from 100% recycled pixels",
        "Open on weekdays!",
        "Open on #{Date.today.strftime("%A")}s",
        "??? profit!",
        "Did you see the price of #{%w[Ðogecoin ₿itcoin Ξtherium].sample}?!",
        "Guess how much it costs to run this thing!",
        "Bytes served fresh daily by Heroku",
        "Running with Ruby on Rails 6",
        "Running on Rails on Ruby",
        "Try saying that 5 times fast!",
        "Try saying it backwards 3 times fast!",
        "Now with 0% interest!",
        "0% interest, but we still think you're interesting",
        "Your project is interesting, even if it gets 0% interest",
        "Achievement unlocked!",
        "20,078 lines of code",
        "Now you have two problems",
        "It's #{%w[collaborative multiplayer].sample} #{%w[venmo cashapp paypal finance banking].sample}!",
        "Fake it till you make it!",
        "Your move, Robinhood",
        "If you can read this, the page's status code is 200",
        "If you can read this, the page has loaded",
        "Now go and buy yourself something nice",
        "[Insert splash text here]",
        "<img src='https://cloud-cno1f4man-hack-club-bot.vercel.app/0zcbx5dwld8161.png' style='transform:translateX(-1rem);width:2rem;height:auto;margin-right:-1.4em;'>",
        "Absolutely financial!",
        "Positively financial!",
        "Financially fantastic!",
        "Financially positive!",
        "Condemned by Wall Street",
        "Condemned by the finance pope",
        "Condemned by the Space Pope",
        "Condemned by the sheriff of money",
        "Checkmate, Capitalists!",
        "all your bank are belong to us",
        "USD: U SEEING DIS?",
        "Starring: You",
        "Coded on location",
        "The bank that smiles back!",
        "*technically not a bank*",
        "...or was it?",
        "Where no finance has gone before!",
        "Where no money has gone before!",
        "Voted “3rd”",
        "You are now breathing manually",
        "If you can read this, thanks!",
        "(or similar product)",
        "[OK]",
        "tell your parents it's educational",
        "You found the 3rd Easter egg on the site",
        "A proud sponsor of fiscal #{%w[things thingies stuff].sample}",
        "Now with 10% more hacks!",
        "Now with more clubs!",
        "Please stow your money in the upright position",
        "you may now assume the financial position",
        "The best site you’re using right now",
        "no u",
        "The FitnessGram™ Pacer Test is a multistage aerobic capacity test that progressively gets more difficult as it continues",
        "It Is What It Is",
        "est. some time ago",
        "Ya like jazz?",
        "no hack, only bank",
        "Insert token(s)",
        "Receipts or it didn't happen",
        "Carbon positive!",
        "We put the 'dig it' in 'digital'",
        "Made in 🇺🇸",
        "Your move IRS!",
        "The buck stops here",
        "Hack Club Moneybucks",
        "If you know, you know",
        "We put the 'ants' in 'pants'",
        "We used this <a href='https://zephyr.hackclub.com' target='_blank'>to buy a train</a>",
        "Do Only Good Everyday",
        "JavaScript brewed fresh daily",
        "It's our business doing finance with you",
        "Flash plugin failed to load",
        "Cash, checks, and cents, oh my!",
        "ACH, checks, and credit, oh my!",
        "Debit, she said",
        "U want sum bank?",
        "* not #{%w[banc banq].sample}",
        "Our ledger's thicker than a bowl of oatmeal",
        "receptz plzzzz",
        "Reciepts? Receipts? Recepts?",
        "Receipts are kinda like a recipe for money",
        "Receipts are kinda like a recipe for a nonprofit",
        "Receipts are kinda like a recipe for losing money",
        "Check the back of this page for an exclusive promo code!",
        "You've found the 5th easter egg on the site!",
        "Happiness > Wealthiness, but I didn't tell you that",
        "A wallet is fine too",
        "A penny saved...",
        "check... cheque... checkqu?",
        "1...2...3... is this thing on?",
        "Welcome to #{%w[cash money].sample} town, population: you",
        "The buck starts here",
        "So... what's your favorite type of pizza?",
        "<span style='font-size: 2px !important'>If you can read this you've got tiny eyes</span>",
        "Page loaded in: < 24 hrs (I hope)",
        "Old and improved!",
        "Newly loaded!",
        "Refreshing! (if you keep hitting ctrl+R)",
        "Recommended by people somewhere!",
        "Recommended by people in some places!",
        "Recommended by non-profits on this site!",
        "Recommended by me!",
        "Recommended by Hack Club!",
        "Recommended by the recommend-o-tron 3000",
        "Recommended! (probably)",
        "We don't accept tips, but we do take advice!",
        "Please stow your money in the upright and locked position",
        "Can't spend what you don't have!",
        "You can ac-count on us!",
        "We put the 'count' in 'accounting'!",
        "bank is such a weird word... bank bank bank",
        "bank baynk baynik banek bake",
        "Have you ever just said a word so much it loses it's meaning?",
        "Teamwork makes the dreams work!",
        "Teamwork makes the memes work!",
        "Dream work makes the memes work!",
        "Meme work makes the team work!",
        "Don't let your dreams be memes!",
        "<em>Vrooooooommmmmmm!</em>",
        "Loaded in #{rand(10..35)}ms... jk– i don't actually know how long it took",
        "Loaded in #{rand(10..35)}ms... jk– i can't count",
        "Turns out it's hard to make one of these things",
        "Look ma, no articles of incorporation!",
        "Task failed successfully!",
        "TODO: come up with some actual jokes for this box",
        "asdgfhjdk I'm out of jokes",
        "asdgfhjdk I'm out of #{%w[money cash bank finance financial].sample} puns",
        "Send your jokes to bank@hackclub.com",
        "Cha-ching!",
        "Hey there cutie!",
        "You're looking great today :)",
        "Great! You're here!",
        "No time to explain: #{%w[quack bark honk].sample} as loud as you can!",
        "Please see attached #{%w[gif avi mp3 wav zip].sample}",
        "Cont. on page 42",
        "See fig. 42",
        "<span class='hide-print'>Try printing this, I dare you</span><span class='hide-non-print'>YOU FOOL</span>",
        "<em>SUPREME</em>",
        "You need to wake up",
        "The only bank brave enough to say '#{%w[sus poggers pog oops uwu].sample}'",
        "Fees lookin pretty sus",
        "Are you suuuuure you aren't a robot?",
        "#{%w[laugh cry smile giggle smirk].sample} here if you aren't a robot",
        "Show emotion here if you aren't a robot",
        "<a href='/robots.txt' target='_blank'>Click here if you are a robot</a>",
        "Robot? <a href='/robots.txt' target='_blank'>Click here</a>",
        "Your ad here!",
        "Make sure your homework is submitted and readable! 👀",
        "What the dollar doin?",
        "Did you mean \"Hack Club Bonk\"?",
        "Did you mean \"Hack Club is jank\"?",
        "Did you mean \"<a href='https://zephyr.hackclub.com' target='_blank'>Hack Club Train</a>\"?",
        "Are you feeling lucky?",
        "Not our fault if it ain't in the vault!",
        "...and you can take that to the bank",
        "Hello <span class='md-hide lg-hide'>tiny</span><span class='sm-hide xs-hide'>large</span>-screened person!",
        "Do you have enough money? I'm positive!",
        "Putting the 'sus' in 'financial sustainability'",
        "Ever just wonder... why?",
        "asljhdjhakshjdahkdshaksdhaks",
        "Birds aren't real!",
        "Wahoo! 🐟",
        "Redstone update out now!",
        "financial edition",
        "educational edition",
        "non-profit edition",
        "non-educational edition",
        "Where's the money lebowski?!",
        "We put the 'poggers' in 'taxes' (there isn't any)",
        "We put the 'fun' in 'accrual-based accounting' (there isn't any)",
        "<a href='https://hack.af/hcb-stickers?prefill_Recipient%20Name=#{current_user.full_name}&prefill_Login%20Email=#{current_user.email}' target='_blank' style='color:#c5ceda;'>Want stickers?</a>",
      ].sample
    end
  end

  def link_to_airtable_task(task_name)
    airtable_info[task_name][:destination]
  end

  def airtable_info
    {
      hackathons: {
        url: "https://airbridge.hackclub.com/v0.1/hackathons.hackclub.com/applications",
        query: { filterByFormula: "AND(Approved=0,Rejected=0)", fields: [] } ,
        destination: "https://airtable.com/tblYVTFLwY378YZa4/viwpJOp6ZmMDfcbgb"
      },
      grant: {
        url: "https://airbridge.hackclub.com/v0.1/Bank%20Promotions/Github%20Grant",
        query: { filterByFormula: "Status='Pending'", fields: [] },
        destination: "https://airtable.com/tblsYQ54Rg1Pjz1xP/viwjETKo05TouqYev"
      },
      stickers: {
        url: "https://airbridge.hackclub.com/v0.1/Bank%20Promotions/Bank%20Stickers",
        query: { filterByFormula: "Status='Pending'", fields: [] },
        destination: "https://airtable.com/tblyhkntth4OyQxiO/viwHcxhOKMZnPXUUU"
      },
      stickermule: {
        url: "https://airbridge.hackclub.com/v0.1/Bank%20Promotions/StickerMule",
        query: { filterByFormula: "Status='Pending'", fields: [] },
        destination: "https://airtable.com/tblwYTdp2fiBv7JqA/viwET9tCYBwaZ3NIq"
      },
      replit: {
        url: "https://airbridge.hackclub.com/v0.1/Bank%20Promotions/Repl.it%20Hacker%20Plan",
        query: {filterByFormula: "Status='Pending'", fields: [] },
        destination: "https://airtable.com/tbl6cbpdId4iA96mD/viw2T8d98ZhhacHCf"
      },
      sendy: {
        url: "https://airbridge.hackclub.com/v0.1/Bank%20Promotions/Sendy",
        query: {filterByFormula: "Status='Pending'", fields: [] },
        destination: "https://airtable.com/tbl1MRaNpF4KphbOd/viwdGjjDdtsS7bjlP"
      },
      pvsa: {
        url: "https://airbridge.hackclub.com/v0.1/Bank%20Promotions/PVSA%20Order",
        query: {filterByFormula: "Status='Pending'", fields: []},
        destination: "https://airtable.com/tbl4ffIbyaEa2fIYW/viw2OPTziXEqOpaLA"
      },
      wire_transfers: {
        url: "https://airbridge.hackclub.com/v0.1/Bank%20Promotions/Wire%20Transfers",
        query: {filterByFormula: "Status='Pending'", fields: [] },
        destination: "https://airtable.com/tbloFbH16HI7t3mfG/viwzgt8VLHOC82m8n"
      },
      paypal_transfers: {
        url: "https://airbridge.hackclub.com/v0.1/Bank%20Promotions/PayPal%20Transfers",
        query: {filterByFormula: "Status='Pending'", fields: [] },
        destination: "https://airtable.com/tbloGiW2jhja8ivtV/viwzhAnWYhpFNhvmC"
      },
    }
  end
end
