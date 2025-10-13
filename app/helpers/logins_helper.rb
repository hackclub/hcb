# frozen_string_literal: true

module LoginsHelper
  HACKATHONS = [
    {
      name: "Assemble",
      time: "Summer 2022",
      slug: "assemble",
      background: "linear-gradient(180deg, rgb(0 0 0 / 20%) 0%, rgba(0 0 0 / 40%) 100%), url('https://cloud-cuely0z02-hack-club-bot.vercel.app/0assemble__2_.jpg')"
    }
  ].map do |hackathon|
    hackathon[:url] = "/#{hackathon[:slug]}"

    hackathon
  end.freeze

  def sample_hackathon
    HACKATHONS.sample(1, random: Random.new(Time.now.to_i / 5.minutes)).first
  end

end
