function ottawaTime = convert_to_ottawa_time(dateDt, utcDateTime)

    dateStr = datestr(dateDt, 'yyyymmdd');
    % Parse the input date string
    date = datetime(dateStr, 'InputFormat', 'yyyyMMdd');

    % Check if it is summer or winter time
    if is_summer_time(date)
        ottawaTimeZone = 'Etc/GMT+4'; % DST timezone for UTC-4
    else
        ottawaTimeZone = 'Etc/GMT+5'; % Standard timezone for UTC-5
    end

    % Set the timezone of the utcDateTime to UTC for conversion
    utcDateTime.TimeZone = 'UTC';

    % Convert the UTC datetime to Ottawa time
    ottawaTime = utcDateTime;
    ottawaTime.TimeZone = ottawaTimeZone;
end
