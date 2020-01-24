# frozen_string_literal: true

class Scheduler::ScheduledStatusesScheduler
  include Sidekiq::Worker

  sidekiq_options unique: :until_executed, retry: 0

  def perform
    publish_scheduled_statuses!
    publish_scheduled_announcements!
    unpublish_expired_announcements!
  end

  private

  def publish_scheduled_statuses!
    due_statuses.find_each do |scheduled_status|
      PublishScheduledStatusWorker.perform_at(scheduled_status.scheduled_at, scheduled_status.id)
    end
  end

  def due_statuses
    ScheduledStatus.where('scheduled_at <= ?', Time.now.utc + PostStatusService::MIN_SCHEDULE_OFFSET)
  end

  def publish_scheduled_announcements!
    due_announcements.find_each do |announcement|
      PublishScheduledAnnouncementWorker.perform_at(announcement.scheduled_at, announcement.id)
    end
  end

  def due_announcements
    Announcement.unpublished.where('scheduled_at IS NOT NULL AND scheduled_at <= ?', Time.now.utc + PostStatusService::MIN_SCHEDULE_OFFSET)
  end

  def unpublish_expired_announcements!
    expired_announcements.in_batches.update_all(published: false)
  end

  def expired_announcements
    Announcement.published.where('ends_at IS NOT NULL AND ends_at <= ?', Time.now.utc)
  end
end
