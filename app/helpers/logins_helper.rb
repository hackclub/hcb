# frozen_string_literal: true

module LoginsHelper
  HACKATHONS = [
    {
      name: "Assemble",
      time: "Summer 2022",
      slug: "assemble",
      background: "linear-gradient(180deg, rgb(0 0 0 / 20%) 0%, rgba(0 0 0 / 40%) 100%), url('https://cdn.hackclub.com/rescue?url=https://hc-cdn.hel1.your-objectstorage.com/s/v3/d925f56a1bc5d118_189933158-9f00ceaf-7f61-4bef-9911-4cf4a14e0e4d.jpeg')"
    }
  ].map do |hackathon|
    hackathon[:url] = "/#{hackathon[:slug]}"

    hackathon
  end.freeze

  def sample_hackathon
    HACKATHONS.sample(1, random: Random.new(Time.now.to_i / 5.minutes)).first
  end

end
