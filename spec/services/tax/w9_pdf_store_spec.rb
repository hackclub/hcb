# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tax::W9PdfStore do
  # The app's test cache is a NullStore, which the store deliberately refuses to
  # write to, so give it something that actually remembers.
  around do |example|
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rails.cache = original
  end

  let(:pdf) { "%PDF-1.4\nsigned W-9\n%%EOF".b }

  it "returns the stored PDF for a valid token" do
    expect(described_class.claim(described_class.store(pdf))).to eq(pdf)
  end

  it "gives every stored PDF a distinct, high-entropy token" do
    tokens = Array.new(5) { described_class.store(pdf) }

    expect(tokens.uniq.size).to eq(5)
    expect(tokens).to all(have_attributes(length: be >= 40))
  end

  it "refuses anything that isn't a PDF" do
    expect { described_class.store("<html>gotcha</html>") }.to raise_error(described_class::NotAPdf)
  end

  it "refuses a PDF over the size limit" do
    oversized = "%PDF-#{"x" * described_class::MAX_BYTES}"

    expect { described_class.store(oversized) }.to raise_error(described_class::TooLarge)
  end

  it "refuses to stage anything when the cache can't remember it" do
    Rails.cache = ActiveSupport::Cache::NullStore.new

    expect { described_class.store(pdf) }.to raise_error(described_class::CacheUnavailable)
  end

  it "expires an unfetched PDF on its own" do
    token = described_class.store(pdf)

    travel(described_class::UNFETCHED_TTL + 1.minute) do
      expect(described_class.claim(token)).to be_nil
    end
  end

  describe "after the first fetch" do
    it "still serves a retry inside the grace period" do
      token = described_class.store(pdf)
      described_class.claim(token)

      travel(described_class::GRACE_PERIOD - 1.second) do
        expect(described_class.claim(token)).to eq(pdf)
      end
    end

    it "is unreachable once the grace period is over" do
      token = described_class.store(pdf)
      described_class.claim(token)

      travel(described_class::GRACE_PERIOD + 1.second) do
        expect(described_class.claim(token)).to be_nil
      end
    end

    it "does not let repeat fetches extend the grace period" do
      token = described_class.store(pdf)
      described_class.claim(token)

      # A second read halfway through must not restart the clock: the PDF is
      # still gone one grace period after the *first* fetch.
      travel(described_class::GRACE_PERIOD / 2) { described_class.claim(token) }
      travel(described_class::GRACE_PERIOD + 1.second) do
        expect(described_class.claim(token)).to be_nil
      end
    end

    it "does not cut an unfetched PDF's life short" do
      token = described_class.store(pdf)

      travel(described_class::GRACE_PERIOD + 1.second) do
        expect(described_class.claim(token)).to eq(pdf)
      end
    end
  end

  it "makes a discarded PDF immediately unreachable" do
    token = described_class.store(pdf)
    described_class.discard(token)

    expect(described_class.claim(token)).to be_nil
  end

  it "returns nil for a token it never issued" do
    expect(described_class.claim(SecureRandom.urlsafe_base64(32))).to be_nil
    expect(described_class.claim(nil)).to be_nil
    expect(described_class.claim("")).to be_nil
  end

  it "does not use the raw token as the cache key" do
    token = described_class.store(pdf)

    expect(Rails.cache.instance_variable_get(:@data).keys.join).not_to include(token)
  end
end
