namespace :cron do
  desc "Run the lunar phase email job (sends only on a principal phase / special moon day)"
  task lunar_phase_email: :environment do
    # Runs the per-phase email job synchronously so a one-off invocation (ECS
    # scheduled task) actually executes the work. On a normal day it detects no
    # principal phase / special moon and exits without sending.
    puts "Starting LunarPhaseEmailJob..."
    # If a DATABASE_URL is present, ensure ActiveRecord connects to it.
    if ENV["DATABASE_URL"]
      begin
        puts "Establishing DB connection from DATABASE_URL"
        ActiveRecord::Base.establish_connection(ENV["DATABASE_URL"])
        # touch the connection to raise early if it fails
        ActiveRecord::Base.connection
        puts "Connected to database via DATABASE_URL"
      rescue => e
        puts "ERROR: failed to connect using DATABASE_URL: #{e.class}: #{e.message}"
        raise
      end
    end

    LunarPhaseEmailJob.perform_now
    puts "LunarPhaseEmailJob complete."
  end
end
