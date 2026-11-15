# frozen_string_literal: true

class DisposableEmailDomainListUpdateJob < ApplicationJob
  queue_as :default

  def perform(*args)
    Nondisposable::DomainListUpdater.update
  end

end
