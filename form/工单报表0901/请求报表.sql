SELECT
	gr.workflow_id AS '请求单号',
	gr.NAME AS '标题',
	gr.applicant AS '申请人',
	bg.NAME AS '申请人单位',
	pt1.assignee_name AS '响应人',
	pt1.assignee_name AS '处理人',

	
	CASE
		gr.state 
		WHEN 'FINISHED' THEN
		"已完成" 
		WHEN 'CANCELED' THEN
		"已取消" 
		WHEN 'STARTED' THEN
		"已开始"
		WHEN 'TIMEOUT_CLOSED' THEN
		"已超时"
	END '工单状态',
	
	JSON_UNQUOTE(JSON_EXTRACT(gr.process_form,'$.service_type')) as '服务类别',
	(select name from user where  id =JSON_UNQUOTE(JSON_EXTRACT(gr.process_form,'$.end_user'))) as '最终用户',
	
	gr.created_at AS '申请时间点',
	pt1.assign_time AS '响应时间点',
	pt1.assign_time AS '开始时间点',
	gr.complete_at AS '完成时间点',
IF
	( pt1.assign_time, TIMESTAMPDIFF( MINUTE, gr.created_at, pt1.assign_time ), '-' ) AS '响应时长(分钟)',
IF
	( pt1.complete_at, TIMESTAMPDIFF( MINUTE, gr.created_at, gr.complete_at ), '-' ) AS '完成时长(分钟)',
	JSON_EXTRACT( pt2.form, '$.fuwu' ) AS '服务评价',
IF
	( grl1.incidentNumbers IS NOT NULL, '是', '否' ) AS '是否转事件',
	grl1.incidentNumbers AS '事件编号',
IF
	( grl2.changeNumbers IS NOT NULL, '是', '否' ) AS '是否转变更',
	grl2.changeNumbers AS '变更编号',
	gr.description AS '备注' 
FROM
	generic_request gr
	LEFT JOIN (
	SELECT
		a.request_id,
		a.form,
		a.assign_time,
		a.process_task_name,
		a.complete_at,
		a.assignee_name 
	FROM
		process_task AS a
		LEFT JOIN ( SELECT max( created_at ) AS create_at, request_id, process_task_name FROM process_task GROUP BY request_id, process_task_name ) AS b ON a.request_id = b.request_id 
	WHERE
		a.created_at = b.create_at 
	) AS pt1 ON gr.id = pt1.request_id 
	AND pt1.process_task_name = '服务处理'
	LEFT JOIN (
	SELECT
		c.request_id,
		c.form,
		c.assign_time,
		c.process_task_name,
		c.assignee_name 
	FROM
		process_task AS c
		LEFT JOIN ( SELECT max( created_at ) AS create_at, request_id, process_task_name FROM process_task GROUP BY request_id, process_task_name ) AS d ON c.request_id = d.request_id 
	WHERE
		c.created_at = d.create_at 
	) AS pt2 ON gr.id = pt2.request_id 
	AND pt2.process_task_name = '确认关闭'
	LEFT JOIN (
	SELECT
		f.source_id,
		group_concat( f.workflow_id, ',' ) AS incidentNumbers 
	FROM
		(
		SELECT
			t1.source_id,
			t2.workflow_id 
		FROM
			generic_request_link t1
			LEFT JOIN generic_request t2 ON t1.target_id = t2.id 
			AND t2.type = 'INCIDENT_SERVICE' 
		) AS f 
	GROUP BY
		f.source_id 
	) AS grl1 ON gr.id = grl1.source_id
	LEFT JOIN (
	SELECT
		f.source_id,
		group_concat( f.workflow_id, ',' ) AS changeNumbers 
	FROM
		(
		SELECT
			t1.source_id,
			t2.workflow_id 
		FROM
			generic_request_link t1
			LEFT JOIN generic_request t2 ON t1.target_id = t2.id 
			AND t2.type = 'CHANGE_SERVICE' 
		) AS f 
	GROUP BY
		f.source_id 
	) AS grl2 ON gr.id = grl2.source_id
	LEFT JOIN business_group bg ON bg.id = gr.business_group_id 
WHERE 

	gr.workflow_id LIKE 'SR%'
	#if(${created_at} != '') 
    AND gr.created_at >= STR_TO_DATE(CONCAT('${created_at}', '-01'),'%Y-%m-%d')
		and gr.created_at <= STR_TO_DATE(CONCAT('${created_at}', '-31'),'%Y-%m-%d')
 #end
	AND gr.applicant NOT LIKE 'System administrator' AND gr.applicant NOT LIKE 'lxp' AND gr.applicant NOT LIKE 'litong' ;