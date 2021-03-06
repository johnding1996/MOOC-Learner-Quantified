DROP FUNCTION IF EXISTS `moocdb`.get_number_of_session_per_video;

CREATE FUNCTION get_number_of_session_per_video (VIDEO_ID VARCHAR(63))
    RETURNS FLOAT
    NOT DETERMINISTIC
BEGIN
  DECLARE frequency INT DEFAULT 0;
  DECLARE loop_flag BOOLEAN DEFAULT FALSE;
  DECLARE event_type VARCHAR(255) DEFAULT NULL;
  DECLARE repeat_flag BOOLEAN DEFAULT FALSE;
  DECLARE cur_time_stamp TIMESTAMP;
  DECLARE prev_time_stamp TIMESTAMP;
  DECLARE cur_user_id VARCHAR(63) DEFAULT NULL;
  DECLARE prev_user_id VARCHAR(63) DEFAULT NULL;
  DECLARE cur CURSOR FOR SELECT observed_event_type, observed_event_timestamp, user_id
    FROM `moocdb`.click_events AS click_events
    WHERE click_events.video_id = VIDEO_ID
    	AND (click_events.observed_event_type = 'load_video'
            OR click_events.observed_event_type = 'play_video'
            OR click_events.observed_event_type = 'pause_video')
    ORDER BY user_id, observed_event_timestamp;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET loop_flag = TRUE;
  SET frequency = 0;
  OPEN cur;
  cum_loop: LOOP
    FETCH cur INTO event_type, cur_time_stamp, cur_user_id;
    IF loop_flag THEN
      LEAVE cum_loop;
    END IF;
    IF prev_user_id != cur_user_id THEN
        SET repeat_flag = FALSE;
    END IF;
    IF event_type = 'load_video' THEN
        IF NOT repeat_flag THEN
            SET repeat_flag = TRUE;
            SET frequency = frequency + 1;
        END IF;
        SET prev_time_stamp = cur_time_stamp;
        SET prev_user_id = cur_user_id;
        ITERATE cum_loop;
    END IF;
    IF TIMESTAMPDIFF(MINUTE, prev_time_stamp, cur_time_stamp) > 30 AND repeat_flag THEN
        SET repeat_flag = FALSE;
        SET frequency = frequency + 1;
    END IF;
    SET prev_time_stamp = cur_time_stamp;
    SET prev_user_id = cur_user_id;
  END LOOP;
  CLOSE cur;
  RETURN frequency;
END;

INSERT INTO `moocdb`.video_feature(feature_id, video_id, feature_value, date_of_extraction)
SELECT 732,
	video_axis.video_id,
	(
	    SELECT feature_value
	    FROM `moocdb`.video_feature AS video_feature
	    WHERE video_feature.feature_id = 722
	        AND video_feature.video_id = video_axis.video_id
	)
	/
	NULLIF(get_number_of_session_per_video(video_axis.video_id), 0),
    CURRENT_TIMESTAMP
FROM `moocdb`.video_axis AS video_axis
;