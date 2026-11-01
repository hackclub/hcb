# frozen_string_literal: true

module Tax
  # Holds a completed W-9 PDF just long enough for TaxBandits to fetch it once,
  # and nowhere else. These PDFs carry a full, unmasked TIN plus a signature, so
  # they must never reach S3, ActiveStorage, the database, or disk: this store
  # keeps them only in the shared cache (Redis in production), which is memory
  # that HCB never backs up and never indexes.
  #
  # The URL handed to TaxBandits is the only thing that authorizes a read, so it
  # carries 256 bits of entropy and is single-use. Three things bound the window
  # in which a leaked URL is worth anything:
  #
  #   * UNFETCHED_TTL — if TaxBandits never comes for it, it expires on its own.
  #   * the first successful read burns it, collapsing its life to GRACE_PERIOD.
  #   * GRACE_PERIOD — a retry of the *same* fetch (a dropped connection, a
  #     re-read at a later processing stage) still succeeds, but only for a
  #     minute, after which the bytes are unreachable for good. The grace window
  #     runs from the first read and is never extended by later ones, so repeated
  #     reads cannot hold the PDF open.
  #
  # Nothing here ever logs the token. Callers must not either.
  class W9PdfStore
    # How long an unfetched PDF survives. TaxBandits fetches PdfUrl while it
    # processes the WhCertificate/Create call, so this only has to outlast their
    # queue, not an admin's working session.
    UNFETCHED_TTL = 1.hour

    # How long the bytes stay readable after the first successful fetch.
    GRACE_PERIOD = 1.minute

    # A signed W-9 is a page or two. Anything appreciably larger is a mistake,
    # and large values in Redis are their own problem.
    MAX_BYTES = 10.megabytes

    CONTENT_TYPE = "application/pdf"

    class TooLarge < StandardError; end
    class NotAPdf < StandardError; end
    class CacheUnavailable < StandardError; end

    Entry = Struct.new(:data, :fetched_at, keyword_init: true)

    class << self
      # Returns the token that addresses the stored PDF. The caller is
      # responsible for putting it in a URL and for calling .discard if the
      # submission it was stored for never happens.
      def store(data)
        data = data.read if data.respond_to?(:read)
        data = data.to_s.b

        raise TooLarge, "W-9 PDF is #{data.bytesize} bytes (max #{MAX_BYTES})" if data.bytesize > MAX_BYTES
        raise NotAPdf, "uploaded file is not a PDF" unless data.start_with?("%PDF-")

        # With a null store every write silently succeeds and every read returns
        # nil, so TaxBandits would fetch a 404 and accept the submission without
        # the PDF. Fail here instead, where it is obvious what went wrong.
        # (Development defaults to a null store until `bin/rails dev:cache` is run.)
        if Rails.cache.is_a?(ActiveSupport::Cache::NullStore)
          raise CacheUnavailable, "the cache store is a NullStore, so the W-9 PDF cannot be staged for TaxBandits"
        end

        token = SecureRandom.urlsafe_base64(32)
        Rails.cache.write(key_for(token), Entry.new(data:, fetched_at: nil), expires_in: UNFETCHED_TTL)

        token
      end

      # Reads the PDF and burns the token: the first call starts GRACE_PERIOD,
      # after which the bytes are gone. Returns nil once the token is spent or
      # was never valid — callers must not distinguish the two to the client.
      def claim(token)
        return nil if token.blank?

        key = key_for(token)
        entry = Rails.cache.read(key)
        return nil if entry.nil?

        if entry.fetched_at.nil?
          # Shorten the entry's life to the grace window. Deliberately only on
          # the first read: re-reading must not keep renewing the window.
          Rails.cache.write(key, Entry.new(data: entry.data, fetched_at: Time.current), expires_in: GRACE_PERIOD)
        end

        entry.data
      end

      # Removes the PDF immediately. Called when the submission the PDF was
      # staged for fails, so a PDF nobody will fetch doesn't sit out its TTL.
      def discard(token)
        return if token.blank?

        Rails.cache.delete(key_for(token))
      end

      private

      def key_for(token)
        # Digested rather than interpolated so the raw token isn't what's sitting
        # in Redis' keyspace, where it would show up in KEYS/MONITOR output and
        # in any cache instrumentation that logs key names.
        "tax/w9_pdf/#{OpenSSL::Digest::SHA256.hexdigest(token)}"
      end

    end

  end
end
