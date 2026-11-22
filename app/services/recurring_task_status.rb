# Last/next run of a Solid Queue recurring task (config/recurring.yml), for
# display. nil where Solid Queue isn't the job backend (development, tests).
class RecurringTaskStatus
  Status = Data.define(:last_run, :next_run)

  def self.for(key)
    return nil unless Rails.application.config.active_job.queue_adapter == :solid_queue

    task = SolidQueue::RecurringTask.find_by(key: key)
    return nil unless task

    last = SolidQueue::RecurringExecution.where(task_key: key).maximum(:run_at)
    Status.new(last_run: last, next_run: task.next_time)
  rescue ActiveRecord::ActiveRecordError
    nil
  end
end
