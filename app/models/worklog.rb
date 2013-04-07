class Worklog < ActiveRecord::Base
  include HourlyRateHelper
  include TotalHelper

  include TimeFilter

  attr_accessible :client_id,
    :end_time,
    :start_time,
    :user_id,
    :hourly_rate,
    :custom_rate,
    :total,
    :summary,
    :from_date,
    :from_time,
    :to_date,
    :to_time

  attr_accessor :from_date,
    :from_time,
    :to_date,
    :to_time

  belongs_to :user
  belongs_to :client
  belongs_to :invoice

  validates :user, :client, :start_time, :end_time, presence: true

  validate :end_time_greater_than_start_time
  validate :duration_less_than_a_year

  after_validation :set_hourly_rate
  after_validation :set_total

  scope :paid, where(invoice_id: !nil)
  scope :unpaid, where(invoice_id: nil)
  scope :no_invoice, where(invoice_id: nil)
  scope :oldest_first, order("end_time ASC")

  def self.to_csv(worklogs)
    CSV.generate do |csv|
      csv << self.columns_to_export
      worklogs.each do |worklog|
        csv << worklog.array_data_to_export
      end
    end
  end

  def self.range_duration_seconds(worklogs)
    return 0 if worklogs.empty?
    sum_start = worklogs.map{|w| w.start_time.to_i}.reduce(:+)
    sum_end = worklogs.map{|w| w.end_time.to_i}.reduce(:+)
    sum_end - sum_start
  end

  def self.hours_from_seconds(seconds)
    seconds / 1.hour
  end

  def self.remaining_minutes_from_seconds(seconds)
    seconds / 1.minute % 60
  end

  def self.columns_to_export
    ["Client", "Start time", "End time", "Hours", "Minutes", "Hourly Rate", "Total", "Summary"]
  end

  def array_data_to_export
    [client.name,
    I18n.localize(start_time),
    I18n.localize(end_time),
    duration_hours,
    duration_minutes,
    hourly_rate,
    total.to_s,
    summary]
  end

  def invoiced?
    invoice_id
  end

  def yes_or_no_boolean(boolean_var)
    boolean_var ? "Yes" : "No"
  end

  def duration
    return if !end_time || !start_time
    (end_time - start_time).to_i
  end

  def duration_hours
    self.class.hours_from_seconds duration
  end

  def duration_minutes
    self.class.remaining_minutes_from_seconds duration
  end

  def calc_total
    return (Money.new cent_rate_per_second(custom_rate_cents) * duration, currency) if custom_rate && custom_rate.cents != 0
    Money.new cent_rate_per_second(hourly_rate_cents) * duration, currency
  end

  def cent_rate_per_second(cents)
    cents.to_f / 3600
  end

  def end_time_ok
    return if !end_time || !start_time
    end_time > start_time
  end

  def set_time_helpers_to_now!
    set_time_helpers_to_time!(Time.zone.now, Time.zone.now)
  end

  def set_time_helpers_to_saved_times!
    set_time_helpers_to_time!(start_time, end_time)
  end

  def set_time_helpers_to_time!(start_time, end_time)
    self.from_date = start_time.strftime("%d/%m/%Y")
    self.to_date = end_time.strftime("%d/%m/%Y")
    self.from_time = start_time.strftime("%H:%M:%S")
    self.to_time = end_time.strftime("%H:%M:%S")
  end

  def from_converted
    begin
      date = self.from_date.split("/").reverse.map(&:to_i)
      time = self.from_time.split(":").map(&:to_i)
      from_to_time(date, time)
    rescue
      nil
    end
  end


  def from_to_time(date, time)
    Time.zone.local(date[0], date[1], date[2], time[0], time[1], time[2])
  end

  def to_converted
    begin
      date = self.to_date.split("/").reverse.map(&:to_i)
      time = self.to_time.split(":").map(&:to_i)
      from_to_time(date, time)
    rescue
      nil
    end
  end

  def convert_time_helpers_to_date_time!
    self.start_time = from_converted
    self.end_time = to_converted
  end

  def restore_based_on_saved_info
    return if !user
    self.class.new(user.temp_worklog_save.restoreable_options)
  end

  def title
    "#{end_time.strftime("%d.%m.%Y")} - #{duration_hours.to_s}h:#{duration_minutes.to_s}min. #{total.to_s}#{total.currency.symbol}"
  end

  def invoice_title(invoice)
    "Work: #{end_time.strftime("%d.%m.%Y")} - #{duration_hours.to_s}h:#{duration_minutes.to_s}min. #{total.to_s}#{total.currency.symbol}"
  end

  def custom_rate
    Money.new custom_rate_cents, currency
  end

  def custom_rate_with_currency
    "#{custom_rate.to_s}#{custom_rate.currency.symbol}"
  end

  def custom_rate=(new_amount)
    return unless new_amount

    if new_amount.is_a?(Money)
      write_attribute(:custom_rate_cents, new_amount.cents)
      result = new_amount
    elsif new_amount.is_a?(Integer)
      write_attribute(:custom_rate_cents, new_amount)
      result = Money.new(new_amount, currency)
    elsif new_amount.is_a?(String) && new_amount.to_i
      amount_from_string = (new_amount.to_f * 100).to_i
      write_attribute(:custom_rate_cents, amount_from_string)
      result = Money.new(amount_from_string, currency)
    end
    result
  end

  # Active record callbacks #

  def set_hourly_rate
    self.hourly_rate = client.hourly_rate
  end

  def set_total
    self.total = self.calc_total
  end

  # Validations #
  def multi_errors_add(attributes, message)
    attributes.each do |attri|
      errors.add(attri, message)
    end
  end

  def duration_less_than_a_year
    if duration && duration > 1.year && end_time_ok
      multi_errors_add([:start_time, :end_time, :from_date, :from_time, :to_time, :to_date], "Must be smaller than a year")
    end
  end

  def end_time_greater_than_start_time
    if !end_time_ok
      multi_errors_add([:end_time, :to_time, :to_date], "Must be greater than the start.")
    end
  end

end
