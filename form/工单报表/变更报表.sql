SELECT
gr.workflow_id AS '变更编号',
       gr.name AS '标题',
       gr.applicant AS  '申请人',
			 (SELECT name FROM business_group WHERE id =gr.business_group_id) '所属业务组',
       pt1.assignee_name as '执行人',
			 
CASE
		gr.state
		WHEN 'FINISHED' THEN
		"已完成" 
		WHEN 'CANCELED' THEN
		"已取消" 
		WHEN 'STARTED' THEN
		"已开始"
		WHEN 'FAILED' THEN
		"已失败"
		WHEN 'TIMEOUT_CLOSED' THEN
		"已超时"
		WHEN 'APPROVAL_RETREATED' THEN
		"已撤回"
		WHEN 'APPROVAL_REJECTED' THEN
		"已拒绝"
	END '工单状态',
	
       JSON_UNQUOTE(JSON_EXTRACT(gr.process_form,'$.change_type')) AS '变更类型',
       JSON_UNQUOTE(JSON_EXTRACT(gr.process_form,'$.change_env')) AS '变更实施环境',
       JSON_UNQUOTE(JSON_EXTRACT(gr.process_form,'$.change_sort'))  AS '变更分类',
       gr.created_at AS '申请时间',
       FROM_UNIXTIME(JSON_EXTRACT(gr.process_form,'$.start_time') / 1000)  AS '预期开始时间',
       FROM_UNIXTIME(JSON_EXTRACT(gr.process_form,'$.end_time')  / 1000) AS '预约结束时间',
       FROM_UNIXTIME(JSON_EXTRACT(pt1.form,'$.zhixing_start_time')/ 1000) AS '执行开始时间',
       FROM_UNIXTIME(JSON_EXTRACT(pt1.form,'$.zhixing_end_time')/ 1000) AS '执行结束时间',
       IF(JSON_EXTRACT(gr.process_form,'$.start_time') & JSON_EXTRACT(gr.process_form,'$.end_time'),TIMESTAMPDIFF(HOUR, JSON_EXTRACT(gr.process_form,'$.start_time'), JSON_EXTRACT(gr.process_form,'$.end_time')),'-') AS '目标使用时长',
       IF(JSON_EXTRACT(pt1.form,'$.zhixing_start_time') & JSON_EXTRACT(pt1.form,'$.zhixing_end_time'),TIMESTAMPDIFF(HOUR, JSON_EXTRACT(pt1.form,'$.zhixing_start_time'), JSON_EXTRACT(pt1.form,'$.zhixing_end_time')),'-') AS '实际使用时长',
       JSON_EXTRACT(pt1.form,'$.ola') AS '是否满足OLA要求',
       JSON_EXTRACT(pt1.form,'$.aaa') AS '执行结果',
       IF(grl1.requestNumbers is not null,'是','否') AS '是否关联服务请求流程',
       grl1.requestNumbers AS '服务请求编号',
       IF(grl2.incidentNumbers is not null,'是','否') AS '是否关联事件流程',
       grl2.incidentNumbers AS '事件编号',
       grl1.requestNumbers AS  '服务请求编号',
       IF(grl3.problemNumbers is not null,'是','否') AS '是否关联问题流程',
       grl3.problemNumbers AS '问题编号',
       gr.description AS '备注'

FROM generic_request gr
         left join (select a.request_id, a.form, a.assign_time, a.process_task_name, a.complete_at,a.assignee_name
                    from process_task as a
                             left join (select max(created_at) as create_at, request_id, process_task_name
                                        from process_task
                                        group by request_id, process_task_name) as b
                                       on a.request_id = b.request_id
                    where a.created_at = b.create_at) as pt1
                   on gr.id = pt1.request_id and pt1.process_task_name = '服务处理'
         left join (select f.source_id, group_concat(f.workflow_id,',') as  requestNumbers
                    from (select t1.source_id, t2.workflow_id
                          from generic_request_link t1
                                   left join generic_request t2
                                             on t1.target_id = t2.id and t2.type = 'REQUEST_SERVICE') as f
                    group by f.source_id) as grl1
                   on gr.id = grl1.source_id
         left join (select f.source_id, group_concat(f.workflow_id,',') as  incidentNumbers
                    from (select t1.source_id, t2.workflow_id
                          from generic_request_link t1
                                   left join generic_request t2
                                             on t1.target_id = t2.id and t2.type = 'INCIDENT_SERVICE') as f
                    group by f.source_id) as grl2
                   on gr.id = grl2.source_id
         left join (select f.source_id, group_concat(f.workflow_id,',') as problemNumbers
                    from (select t1.source_id, t2.workflow_id
                          from generic_request_link t1
                                   left join generic_request t2
                                             on t1.target_id = t2.id and t2.type = 'CHANGE_SERVICE') as f
                    group by f.source_id) as grl3
                   on gr.id = grl3.source_id
where type ='CHANGE_SERVICE'
#if(${created_at} != '') 
    AND gr.created_at >= STR_TO_DATE(CONCAT('${created_at}', '-01'),'%Y-%m-%d')
      AND gr.created_at <= STR_TO_DATE(CONCAT('${created_at}', '-31'),'%Y-%m-%d')
 #end
AND gr.applicant NOT LIKE 'System administrator' ;
