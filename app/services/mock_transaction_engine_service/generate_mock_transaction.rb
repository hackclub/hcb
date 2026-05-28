# frozen_string_literal: true

module MockTransactionEngineService
  class GenerateMockTransaction
    NEGATIVE_DESCRIPTIONS = [
      { desc: "🌶️ Jalapeños for the steamy social salsa sesh" },
      { desc: "👩‍💻 Payment for club coding lessons (solid gold; rare; imported)" },
      { desc: "🍺 Reimbursement for Friday night's team-building pub crawl" },
      { desc: "😨 Monthly payment to the local protection racket" },
      { desc: "🚀 Rocket fuel for Lucas' commute" },
      { desc: "🎵 Payment for a DJ for the club disco (groovy)" },
      { desc: "🤫 Hush money" },
      { desc: "🦄 Purchase of a cute unicorn for team morale" },
      { desc: "🍌 Bananas (Fairtrade)" },
      { desc: "💸 Withdrawal for emergency pizza run" },
      { desc: "🍔 Withdrawal for a not-so-emergency burger run" },
      { desc: "🧑‍🚀 Astronaut suit for Lucas to get home when it's cold" },
      { desc: "🫘 Chilli con carne (home cooked, just how you like it)" },
      { desc: "🦖 Purchase of a teeny tiny T-Rex" },
      { desc: "🧪 Purchase of lab rats for the club's genetics project" },
      { desc: "🐣 An incubator to help hatch big ideas" },
      { desc: "📈 Financial advisor to teach us better spending tips" },
      { desc: "🐛 Office wormery" },
      { desc: "📹 Webcams for the team x4" },
      { desc: "🪨 Hackathon rock tumbler" },
      { desc: "🌸 Payment for a floral arrangement" },
      { desc: "🧼 Purchase of eco-friendly soap for the club bathrooms" },
    ].freeze
    POSITIVE_DESCRIPTIONS = [
      { desc: "💰 Donation from t̶͖̯́̒̇͝h̸͇̥̘̖̞̋͛̕ę̷̧̯̓̄͜ ̵̧̡̀̎͋̚v̸̰̰̝͈̟̂̇̏̓ͅo̶͓͈͑̑̄̍i̸͉̺͕̥̓̍d̵̟̮̼̠̺̿͌́" },
      { desc: "💰 Donation from the man in the walls", monthly: true },
      { desc: "💰 Donation from Dave from next door", monthly: true },
      { desc: "💰 Donation from Old Greg down hill" },
    ].freeze

    def initialize
      @mock_tx_num = rand(7..10)
      @mock_balance = 0
    end

    def run
      generate_mock_transaction_list.map do |trans|
        OpenStruct.new(
          amount: Money.new(trans[:amount].round(2) * 100),
          amount_cents: (trans[:amount].round(2) * 100).to_i,
          fee_payment?: trans[:desc].include?("💰 Fiscal sponsorship fee"),
          date: trans[:date],
          local_hcb_code: OpenStruct.new(
            memo: trans[:desc],
            receipts: if trans[:amount] > 0 || trans[:desc].include?("💰 Fiscal sponsorship fee")
                        []
                      else
                        Array.new(rand(100) < 90 ? 1 : 0)
                      end, # 90% chance of 1 receipt, 10% chance of no receipts
            comments: Array.new(rand(9) > 1 || trans[:desc].include?("💰 Fiscal sponsorship fee") ? 0 : rand(1..2)), # 1/3 chance of no comments, 2/3 chance of 1 or 2 comments
            donation?: trans[:amount].positive?,
            donation: trans[:amount].positive? ? OpenStruct.new(recurring?: trans[:monthly]) : nil,
            tags: []
          )
        )
      end
    end

    def generate_mock_tx
      NEGATIVE_DESCRIPTIONS[rand(NEGATIVE_DESCRIPTIONS.length)].merge({ amount: rand(0..@mock_balance) * -1 })
    end

    def generate_mock_donation
      POSITIVE_DESCRIPTIONS[rand(POSITIVE_DESCRIPTIONS.length)].merge({ amount: rand(1000) })
    end

    def generate_mock_fiscal_sponsorship_fee(donation_amount)
      { desc: "💰 Fiscal sponsorship fee", amount: -0.07 * donation_amount }
    end

    def generate_mock_transaction_list
      @mock_tx = []
      index = 0
      while index < @mock_tx_num
        if @mock_balance > rand(1..40)
          @mock_tx << generate_mock_tx
          @mock_balance += @mock_tx[index][:amount] # add the negative transaction amount to the balance
          index += 1
        else # else, generate a random donation
          @mock_tx << generate_mock_donation
          @mock_tx << generate_mock_fiscal_sponsorship_fee(@mock_tx.last[:amount])
          @mock_balance += @mock_tx[index][:amount] # add the donation amount to the balance
          @mock_balance += @mock_tx.last[:amount] # add the negative fiscal fee amount to the balance
          index += 2 # increment the index by 2 to account for the donation and the fee
        end
      end

      current_date = DateTime.now
      @mock_tx.reverse.each do |tx|
        random_interval = tx[:desc].include?("💰 Fiscal sponsorship fee") ? 7 : rand(8..180) # If the transaction is not a fiscal sponsorship fee, generate a random interval between 8 and 180 days
        tx[:date] = current_date.strftime("%Y-%m-%d") # Format the date
        current_date -= random_interval # Increment the date by the random interval, or 7 if the transaction is a fiscal sponsorship fee
      end

      @mock_tx.reverse
    end

  end
end
