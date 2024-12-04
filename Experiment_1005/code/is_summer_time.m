function isSummer = is_summer_time(dateStr)
    % Parse the input date string
    date = datetime(dateStr, 'InputFormat', 'yyyyMMdd');

    % Set the time zone for Ottawa
    date.TimeZone = 'America/Toronto';

    % Check if the date is in daylight saving time
    isSummer = isdst(date);
end


