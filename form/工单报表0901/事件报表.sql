SELECT
	gr.workflow_id AS '事件编号',
	gr.name AS '标题',
	gr.applicant AS '响应人',
	pt1.assignee_name AS '处理人',
	JSON_UNQUOTE(
	JSON_EXTRACT( gr.process_form, '$.apply_style' )) AS '受理方式',
CASE
		gr.state 
		WHEN 'FINISHED' THEN
		"已完成" 
		WHEN 'CANCELED' THEN
		"已取消" 
		WHEN 'STARTED' THEN
		"已开始" 
	END '工单状态',
			 
      JSON_UNQUOTE(IF(JSON_EXTRACT(pt1.form,'$.eventform_type') = 'basic',JSON_EXTRACT(pt1.form,'$.event_source'),JSON_EXTRACT(pt1.form,'$.source2')) ) as '事件来源',
      JSON_UNQUOTE(IF(JSON_EXTRACT(pt1.form,'$.eventform_type') = 'basic',JSON_EXTRACT(pt1.form,'$.event_area'),JSON_EXTRACT(pt1.form,'$.area2')) ) as '事件区域',
      JSON_UNQUOTE(IF(JSON_EXTRACT(pt1.form,'$.eventform_type') = 'basic',JSON_EXTRACT(pt1.form,'$.event_influnce'),JSON_EXTRACT(pt1.form,'$.influence2')) ) as '事件影响度',
      JSON_UNQUOTE(IF(JSON_EXTRACT(pt1.form,'$.eventform_type') = 'basic',JSON_EXTRACT(pt1.form,'$.yanzhongxing'),JSON_EXTRACT(pt1.form,'$.severity2')))  as '事件严重性',
      JSON_UNQUOTE(IF(JSON_EXTRACT(pt1.form,'$.eventform_type') = 'basic',JSON_EXTRACT(pt1.form,'$.event_level'),JSON_EXTRACT(pt1.form,'$.level2')))  as '事件级别',
			 
CASE
			JSON_UNQUOTE(IF(JSON_EXTRACT(pt1.form,'$.eventform_type') = 'basic',JSON_EXTRACT(pt1.form,'$.event_type'),JSON_EXTRACT(pt1.form,'$.type2')))
	WHEN 'service' THEN
	"服务请求" 
	WHEN 'error' THEN
	"故障处理" 
	WHEN 'infomation' THEN
	"信息安全" 
	WHEN 'infrastructure' THEN
	'基础设施'
	WHEN 'physical' THEN
  '物理安全'
END '一级分类',

CASE
			JSON_UNQUOTE(IF(JSON_EXTRACT(pt1.form,'$.eventform_type') = 'basic',JSON_EXTRACT(pt1.form,'$.malfunction'),JSON_EXTRACT(pt1.form,'$.malfunction2')))
			WHEN 'equipment' THEN
			"硬件设备故障" 
			WHEN 'software' THEN
			"系统软件故障" 
END '二级分类',
CASE
			JSON_UNQUOTE(IF(JSON_EXTRACT(pt1.form,'$.eventform_type') = 'basic',IF(JSON_EXTRACT(pt1.form,'$.malfunction') = 'equipment',JSON_EXTRACT(pt1.form,'$.equipment_malfunction_type'),JSON_EXTRACT(pt1.form,'$.software_malfunction_type')),IF(JSON_EXTRACT(pt1.form,'$.malfunction2') = 'equipment',JSON_EXTRACT(pt1.form,'$.equipment_malfunction2_type'),JSON_EXTRACT(pt1.form,'$.software_malfunction2_type'))))
			WHEN 'micro_module' THEN
			"X86 设备故障" 
			WHEN 'sde' THEN
			"存储设备故障" 
			WHEN 'ecm' THEN
			"网络设备故障"
			WHEN 'hvac' THEN 
			"安全设备故障"
			WHEN 'cctv' THEN
					IF(JSON_EXTRACT(pt1.form,'$.eventform_type') = 'basic',"安全软件故障","视频监控系统")
			WHEN '微模块设备故障' THEN
			"微模块设备故障"
			WHEN 'su' THEN
			    IF(JSON_EXTRACT(pt1.form,'$.eventform_type') = 'nobasic',"云平台软件故障","动环监控系统故障")
 END '三级分类',
       
gr.created_at AS '发生时间',
pt1.assign_time AS '响应时间',
pt1.complete_at AS '恢复时间',
pt1.complete_at AS '解决时间',
			 
			 FROM_UNIXTIME(IF(JSON_EXTRACT(pt1.form,'$.eventform_type') = 'basic',JSON_EXTRACT(pt1.form,'$.time'),JSON_EXTRACT(pt1.form,'$.time2')) / 1000)  as '通报时间',
       
       IF(pt1.assign_time, TIMESTAMPDIFF(MINUTE, gr.created_at,pt1.assign_time), '-') AS '响应时长(分钟)',
       IF(pt1.complete_at, TIMESTAMPDIFF(MINUTE, gr.created_at,pt1.complete_at), '-')  AS '恢复时长(分钟)',
       IF(pt1.complete_at, TIMESTAMPDIFF(MINUTE, pt1.assign_time,pt1.complete_at), '-')  AS '解决时长(分钟)',
       JSON_EXTRACT(pt1.form,'$.ola') AS '是否满足OLA要求',
       IF(grl2.changeNumbers is not null,'是','否') AS '是否转变更流程',
       grl2.changeNumbers AS '变更编号',
       IF(grl3.problemNumbers is not null,'是','否') AS '是否转问题流程',
       grl3.problemNumbers AS '问题编号',
       gr.description AS '备注'
from generic_request gr
         left join (select a.request_id, a.form, a.assign_time, a.process_task_name, a.complete_at,a.assignee_name
                    from process_task as a
                             left join (select max(created_at) as create_at, request_id, process_task_name
                                        from process_task
                                        group by request_id, process_task_name) as b
                                       on a.request_id = b.request_id
                    where a.created_at = b.create_at) as pt1
                   on gr.id = pt1.request_id and pt1.process_task_name = '一线处理支持'
         left join (select f.source_id, group_concat(f.workflow_id,',') as  changeNumbers
                    from (select t1.source_id, t2.workflow_id
                          from generic_request_link t1
                                   left join generic_request t2
                                             on t1.target_id = t2.id and t2.type = 'CHANGE_SERVICE') as f
                    group by f.source_id) as grl2
                   on gr.id = grl2.source_id
         left join (select f.source_id, group_concat(f.workflow_id,',') as problemNumbers
                    from (select t1.source_id, t2.workflow_id
                          from generic_request_link t1
                                   left join generic_request t2
                                             on t1.target_id = t2.id and t2.type = 'PROBLEM_SERVICE') as f
                    group by f.source_id) as grl3
                   on gr.id = grl3.source_id
where gr.type ='INCIDENT_SERVICE' and gr.state ='FINISHED'
#if(${created_at} != '') 
    AND gr.created_at >= STR_TO_DATE(CONCAT('${created_at}', '-01'),'%Y-%m-%d')
      AND gr.created_at <= STR_TO_DATE(CONCAT('${created_at}', '-31'),'%Y-%m-%d')
 #end
 AND gr.applicant NOT LIKE 'System administrator';
