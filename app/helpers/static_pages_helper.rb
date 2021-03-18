module StaticPagesHelper
  def card_to(name, path, options = {})
    return '' if options[:badge] == 0

    badge = options[:badge].to_i > 0 ? badge_for(options[:badge]) : ''
    link_to content_tag(:li,
                        [content_tag(:strong, name), badge].join.html_safe,
                        class: 'card card--item card--hover relative overflow-visible line-height-3'),
                        path, method: options[:method]
  end

  def random_nickname
    if Rails.env.development?
      'Development Mode'
    else
      [
        'The hivemind known as Bank',
        'A cloud full of money',
        "Hack Club's pot of gold",
        'A sentient stack of dollars',
        'The Hack Club Federal Reserve',
        'money money money money money',
        'A money-crazed virus 🤑',
        'A cloud raining money',
        "A pile of money in the cloud",
        'Hack Club Smoothmunny',
        'Hack Club ezBUCKS',
        'Hack Club Money Bucket',
        'A mattress stuffed with 100 dollar bills', # this is the max length allowed for this header
        'Hack Club Dollaringos',
        'The Hack Foundation dba The Dolla Store',
        'Hack on.',
        'Open on weekends',
        'Open on holidays',
        "please don't hack",
        'HCB– Happily Celebrating Bees',
        'HCB– Hungry Computer Bison',
        'HCB– Huge Cellophane Boats',
        'HCB– Hydrofoils Chartered by Bandits',
        'The best thing since sliced bread',
        'Hack Club Bink',
        'Hack 👏 Club 👏 Bank 👏',
        '💻 ♣ 🏦',
        'aka Hack Bank',
        'aka Hank',
        'Open late',
        'From the makers of Hack Club',
        'Now in color!',
        'Filmed on location',
        'From the makers of Hack Club Bank',
        'Soon to be a major cryptocurrency!',
        'As seen on the internet',
        '👏 KEEP 👏 YOUR 👏 RECEIPTS 👏',
        'Money: collect it all!',
        "Help, I'm trapped in the internet!",
        "Most viewed site on this domain!",
        'Coming to a browser near you',
        'Hand-crafted by our resident byte-smiths',
        'B O N K',
        "#{rand 4..9}0% bug free!",
        "#{rand 1..4}0% less bugs!",
        'Ask your doctor if Hack Club Bank is right for you',
        'Now with "code"',
        'Closed source!',
        'Finally complete!',
        'Internet enabled!',
        "It's finally here!",
        "It's finished!",
        'Holds lots of cents',
        'It just makes cents',
        'By hackers for hackers',
        'Over 100 users!',
        'Over 20 accounts!',
        'Over $1,000,000 served!',
        'One of a kind!',
        'Reticulating splines...',
        'Educational!',
        "Don't use while driving",
        'Support local businesses!',
        'Take frequent breaks!',
        'Technically good!',
        "That's Numberwang!",
        "The bee's knees!",
        'Greater than the sum of its transactions!',
        'Greater than the sum of its donations!',
        'Greater than the sum of its invoices!',
        'Operating at a loss since 2018!',
        'The sum of its parts!',
        'Does anyone actually read this?',
        'Like and subscribe!',
        'Like that smash button!',
        'it protec, and also attac, but most importantly it pay fees back',
        'it secures the bag',
        'Protec but also attac',
        'As seen on bank.hackclub.com',
        'As seen on hackclub.com',
        '2 cool 4 scool',
        'Now running in production!',
        'put money in computer',
        'TODO: get that bread',
        'Coming soon to a screen near your face',
        'Coming soon to a screen year you',
        'As seen on the internet',
        "Operating at a loss so you don't have to",
        'Made by a non-profit for non-profits',
        'By hackers, for hackers',
        'It holds money!',
        'uwu',
        'owo',
        'ovo',
        '(◕‿◕✿)',
        'Red acting kinda sus',
        'An important part of this nutritional breakfast',
        'By people with money, for people with money',
        'Made using "money"',
        'Chosen #1 by dinosaurs everywhere',
        'Accountants HATE him',
        "Congratulations, you are the #{number_with_delimiter(10**rand(1..5))}th visitor!",
        "All the finance that's fit to print",
        "You've got this",
        "Don't forget to drink water!",
        "Putting the 'fun' in 'refund'",
        "Putting the 'fun' in 'fundraising'",
        "Putting the 'do' in 'donate'",
        "Putting the 'fee' in 'free'",
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
        "<script>alert(1);</script>"
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
      wire_transfers: {
        url: "https://airbridge.hackclub.com/v0.1/Bank%20Promotions/Wire%20Transfers",
        query: {filterByFormula: "Status='Pending'", fields: [] },
        destination: "https://airtable.com/tbloFbH16HI7t3mfG/viwzgt8VLHOC82m8n"
      },
    }
  end
end
