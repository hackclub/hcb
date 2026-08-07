# frozen_string_literal: true

module LoginsHelper
  HACKATHONS = [
    {
      name: "Assemble",
      time: "Summer 2022",
      slug: "assemble",
      background: "linear-gradient(180deg, rgb(0 0 0 / 20%) 0%, rgba(0 0 0 / 40%) 100%), url('https://cdn.hackclub.com/019c3145-9292-72ce-9c97-6e2fbddcc559/crowd.jpeg')"
    }
  ].map do |hackathon|
    hackathon[:url] = "/#{hackathon[:slug]}"

    hackathon
  end.freeze

  def sample_hackathon
    HACKATHONS.sample(1, random: Random.new(Time.now.to_i / 5.minutes)).first
  end

end
