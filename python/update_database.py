# -*- coding: utf-8 -*-

#author：wadelai
#date：2021421
'''
功能: 1.查询华为运维页面的数据
     2.写入对应的数据库
'''
import os
import socket
import csv
import requests
import re
import json
import hashlib
import MySQLdb
import urllib
import urllib3
import ssl
import time
import datetime
#urllib3.disable_warnings()
from http.client import HTTPSConnection
from requests.packages.urllib3.exceptions import InsecureRequestWarning
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

ssl._create_default_https_context = ssl._create_unverified_context

alert_dict = {"1": "紧急", "2": "重要", "3": "次要", "4": "提示"}

def md_screen():
    hash = hashlib.md5()
    hash.update(bytes(password,encoding='utf-8'))
    md_password = hash.hexdigest()
    return md_password

def url_token():
    url = 'https://10.230.9.37:26335/rest/plat/smapp/v1/oauth/token'
    data = {
            "grantType": "password",
            "userName": "cmptest",
            "value": "Y@cmp123"
    }
    header = {
             'Content-Type': 'application/json',
             'Accept': '*/*'
    }
    req = requests.put(url, verify=False, json=data, headers=header)


    if req.status_code == 200:
        response_json = json.loads(req.text)
        if type(response_json) == dict:
            token = response_json.get('accessSession')
        else:
            token = ""
        return token
    else:
        print(req.status_code)
        exit(1)


class Api:

    def __init__(self, token):
        self.headers = {
                'Content-Type': 'application/json',
                'Accept': '*/*',
                'X-Auth-Token': token
        }
    def easyrequest(self, uri, method, data):
        url = uri
        if data:
            params = data
        else:
            params = {}
        if method == 'GET':
            response = requests.get(url, verify=False, headers=self.headers)
        if method == 'POST':
            response = requests.post(url,
                                     verify=False, json=params, headers=self.headers)
        if response.status_code == 200:
            try:
                response_json = json.loads(response.text)
                prinyt(response_json)
                return response_json
            except Exception as e:
                return response_json
        else:
            print(response.status_code)
            raise Exception("easyrequest %s return %s %s" % (response.url, response.status_code, response.text))

    def get_instance(self, uri, method):
        response = self.easyrequest(uri=uri, method=method, data={})
        print(len(response['content']))
        return response
    # 获取总的cpu、memory、stage
    def get_all(self):
        uri = 'https://10.230.9.37:26335/rest/capacity/v1/capbase/resource-pools/25216A596C493169B7D106ECB32E83F8/resource-types/cpu,memory,storage-pool/current-capacities'

        res_url = 'https://oc.chengtou.oc.com:26335/rest/capacity/v1/capbase/azones/811370A5736C39E1A2155BB3296136DC/resource-types/cpu,memory,storage-pool/current-capacities'
#          获取分配率所需数据的url
        response = self.easyrequest(uri=uri, method='GET', data={})

        res_resp = self.easyrequest(uri=res_url, method='GET', data={})
#           获取分配率所要用到的回传数据
        print(response)

        print(res_resp)
#           打印回传数据
        memory_ratio = int(response['memory']['oversubscriptionCapacity']['allocatedCapacity']['ratio'])
        memory_type1 = int(float(response['memory']['oversubscriptionCapacity']['allocatedCapacity']['capacityValue']))
        memory_type2 = int(float(response['memory']['oversubscriptionCapacity']['totalCapacity']['capacityValue']))
        cpu_ratio = int(response['cpu']['oversubscriptionCapacity']['allocatedCapacity']['ratio'])
        cpu_type1 = int(float(response['cpu']['oversubscriptionCapacity']['allocatedCapacity']['capacityValue']))
        cpu_type2 = int(float(response['cpu']['oversubscriptionCapacity']['totalCapacity']['capacityValue']))
        stoge_ratio = int(float(response['storagePool']['oversubscriptionCapacity']['allocatedCapacity']['capacityValue']))
        stoge_type2 = 1823
        stoge_ratio2 = int(stoge_ratio/stoge_type2*100)

        cpu_use = int(response['cpu']['actualCapacity']['usedCapacity']['ratio'])
        memory_use = int(response['memory']['actualCapacity']['usedCapacity']['ratio'])
        stoge_use = int(response['storagePool']['actualCapacity']['usedCapacity']['ratio'])

        res_cpu_ratio = int(res_resp['cpu']['oversubscriptionCapacity']['allocatedCapacity']['ratio'])
        # CPU分配率
        res_cpu_type1 = int(float(res_resp['cpu']['oversubscriptionCapacity']['allocatedCapacity']['capacityValue']))
        #CPU用
        res_cpu_type2 = int(float(res_resp['cpu']['oversubscriptionCapacity']['totalCapacity']['capacityValue']))
        # CPU总
        res_mem_ratio = int(res_resp['memory']['oversubscriptionCapacity']['allocatedCapacity']['ratio'])
        res_mem_type1 = int(float(res_resp['memory']['oversubscriptionCapacity']['allocatedCapacity']['capacityValue']))
        res_mem_type2 = int(float(res_resp['memory']['oversubscriptionCapacity']['totalCapacity']['capacityValue']))
        res_stoge_ratio = int(float(res_resp['storagePool']['oversubscriptionCapacity']['allocatedCapacity']['ratio']))
        res_stoge_type1 = int(float(res_resp['storagePool']['oversubscriptionCapacity']['allocatedCapacity']['capacityValue']))
        res_stoge_type2 = int(float(res_resp['storagePool']['oversubscriptionCapacity']['totalCapacity']['capacityValue']))
       # 赋值部分，将已分配和使用的比值等数据从回传数据中过滤，并赋值 

        # 灾备区裸金属
        uri = 'https://10.230.9.37:26335/rest/capacity/v1/capbase/azones/1B4A9EB5CD183134B9E06D9501F791E4/resource-types/cpu,memory,storage-pool/current-capacities'
        uat_bms = self.easyrequest(uri=uri, method='GET', data={})
        uat_bms_cpu = format(uat_bms['cpu']['oversubscriptionCapacity']['allocatedCapacity']['ratio'], '.1f')
        uat_bms_memory = format(uat_bms['memory']['oversubscriptionCapacity']['allocatedCapacity']['ratio'], '.1f')
        uat_bms_stoge = format(uat_bms['storagePool']['oversubscriptionCapacity']['allocatedCapacity']['ratio'], '.1f')
        # 生产区裸金属
        uri = 'https://10.230.9.37:26335/rest/capacity/v1/capbase/azones/B3BC268C699C3C409B755507FB1DB486/resource-types/cpu,memory,storage-pool/current-capacities'
        pro_bms = self.easyrequest(uri=uri, method='GET', data={})
        pro_bms_cpu = format(pro_bms['cpu']['oversubscriptionCapacity']['allocatedCapacity']['ratio'], '.1f')
        pro_bms_memory = format(pro_bms['memory']['oversubscriptionCapacity']['allocatedCapacity']['ratio'], '.1f')
        pro_bms_stoge = format(pro_bms['storagePool']['oversubscriptionCapacity']['allocatedCapacity']['ratio'], '.1f')
        # 灾备区虚拟机
        uri = 'https://10.230.9.37:26335/rest/capacity/v1/capbase/azones/41C0A08C84B4394D81D59B8E60CBD678/resource-types/cpu,memory,storage-pool/current-capacities'
        uat_ecs = self.easyrequest(uri=uri, method='GET', data={})
        uat_ecs_cpu = format(uat_ecs['cpu']['oversubscriptionCapacity']['allocatedCapacity']['ratio'], '.1f')
        uat_ecs_memory = format(uat_ecs['memory']['oversubscriptionCapacity']['allocatedCapacity']['ratio'], '.1f')
        uat_ecs_stoge = format(uat_ecs['storagePool']['oversubscriptionCapacity']['allocatedCapacity']['ratio'], '.1f')
        # 生产区虚拟机
        uri = 'https://10.230.9.37:26335/rest/capacity/v1/capbase/azones/811370A5736C39E1A2155BB3296136DC/resource-types/cpu,memory,storage-pool/current-capacities'
        pro_ecs = self.easyrequest(uri=uri, method='GET', data={})
        pro_ecs_cpu = format(pro_ecs['cpu']['oversubscriptionCapacity']['allocatedCapacity']['ratio'], '.1f')
        pro_ecs_memory = format(pro_ecs['memory']['oversubscriptionCapacity']['allocatedCapacity']['ratio'], '.1f')
        pro_ecs_stoge = format(pro_ecs['storagePool']['oversubscriptionCapacity']['allocatedCapacity']['ratio'], '.1f')
        # 互联网区
        uri = 'https://10.230.9.37:26335/rest/capacity/v1/capbase/azones/DB923D022DA03DE8B7C0C6B5EB4D04D4/resource-types/cpu,memory,storage-pool/current-capacities'
        inter = self.easyrequest(uri=uri, method='GET', data={})
        inter_cpu = format(inter['cpu']['oversubscriptionCapacity']['allocatedCapacity']['ratio'], '.1f')
        inter_memory = format(inter['memory']['oversubscriptionCapacity']['allocatedCapacity']['ratio'], '.1f')
        inter_stoge = format(inter['storagePool']['oversubscriptionCapacity']['allocatedCapacity']['ratio'], '.1f')
        # 测试区
        uri = 'https://10.230.9.37:26335/rest/capacity/v1/capbase/azones/139E610D41E738DBBD31ED6F3D382096/resource-types/cpu,memory,storage-pool/current-capacities'
        test = self.easyrequest(uri=uri, method='GET', data={})
        test_cpu = format(test['cpu']['oversubscriptionCapacity']['allocatedCapacity']['ratio'], '.1f')
        test_memory = format(test['memory']['oversubscriptionCapacity']['allocatedCapacity']['ratio'], '.1f')
        test_stoge = format(test['storagePool']['oversubscriptionCapacity']['allocatedCapacity']['ratio'], '.1f')
	
	
        conn = MySQLdb.Connect(host='172.19.133.13',
                               port=3306,
                               user='cloudchef',
                               passwd='c10udch3f',
                               db='DataVAutoSrc',
                               charset='utf8')
        cur=conn.cursor()
        cur.execute(
            "update resource_ratio set value = {0},used = {1}, total = {2} where name = 'cpu_ra'".format(res_cpu_ratio, res_cpu_type1, res_cpu_type2))
        cur.execute(
            "update resource_ratio set value = {0} where name = 'cpu_use'".format(cpu_use))
        cur.execute(
            "update resource_ratio set value = {0},used = {1}, total = {2} where name = 'memory_ra'".format(res_mem_ratio, res_mem_type1, res_mem_type2))
        cur.execute(
            "update resource_ratio set value = {0} where name = 'memory_use'".format(memory_use))
        cur.execute(
            "update resource_ratio set value = {0}, used = {1}, total = {2} where name = 'storage_ra'".format(res_stoge_ratio, res_stoge_type1, res_stoge_type2))
        cur.execute(
            "update resource_ratio set value = {0} where name = 'storage_use'".format(stoge_use))


        cur.execute(
            "update 6az set hulianwangqu = {0} where name = '互联网区' and id = 1".format(inter_cpu))
        cur.execute(
            "update 6az set hulianwangqu = {0} where name = '互联网区'and id = 2".format(inter_memory))
        cur.execute(
            "update 6az set hulianwangqu = {0} where name = '互联网区' and id = 3".format(inter_stoge))

        cur.execute(
            "update 6az set ceshiqu = {0} where name = '测试区' and id = 1".format(test_cpu))
        cur.execute(
            "update 6az set ceshiqu = {0} where name = '测试区' and id = 2".format(test_memory))
        cur.execute(
            "update 6az set ceshiqu = {0} where name = '测试区' and id = 3".format(test_stoge))

        cur.execute(
            "update 6az set shengluo = {0} where name = '生产区裸金属' and id = 1".format(pro_bms_cpu))
        cur.execute(
            "update 6az set shengluo = {0} where name = '生产区裸金属' and id = 2".format(pro_bms_memory))
        cur.execute(
            "update 6az set shengluo = {0} where name = '生产区裸金属' and id = 3".format(pro_bms_stoge))

        cur.execute(
            "update 6az set zailuo = {0} where name = '灾备区裸金属' and id = 1".format(uat_bms_cpu))
        cur.execute(
            "update 6az set zailuo = {0} where name = '灾备区裸金属' and id = 2".format(uat_bms_memory))
        cur.execute(
            "update 6az set zailuo = {0} where name = '灾备区裸金属' and id = 3".format(uat_bms_stoge))

        cur.execute(
            "update 6az set shengvm = {0} where name = '生产区虚拟机' and id = 1".format(pro_ecs_cpu))
        cur.execute(
            "update 6az set shengvm = {0} where name = '生产区虚拟机' and id = 2".format(pro_ecs_memory))
        cur.execute(
            "update 6az set shengvm = {0} where name = '生产区虚拟机' and id = 3".format(pro_ecs_stoge))

        cur.execute(
            "update 6az set zaivm = {0} where name = '灾备区虚拟机' and id = 1".format(uat_ecs_cpu))
        cur.execute(
            "update 6az set zaivm = {0} where name = '灾备区虚拟机' and id = 2".format(uat_ecs_memory))
        cur.execute(
            "update 6az set zaivm = {0} where name = '灾备区虚拟机' and id = 3".format(uat_ecs_stoge))
        conn.commit()
        conn.close()


    def get_alert(self):
        # 获取已处理告警数量
        #获取前七天的数据
        conn = MySQLdb.Connect(host='172.19.133.13',
                               port=3306,
                               user='cloudchef',
                               passwd='c10udch3f',
                               db='DataVAutoSrc',
                               charset='utf8')
        cur = conn.cursor()
        date = datetime.datetime.now().strftime("%Y-%m-%d")
        date7 = (datetime.datetime.now() + datetime.timedelta(days=-7)).strftime("%Y-%m-%d")
        sql = "SELECT count(*) from alert_count where errortime = '{}'".format(
            date7)
        cur.execute(sql)
        # 获取所有记录列表
        results = cur.fetchall()
        #如果有返回说明需要删除新建，否则就更新即可
        if results[0][0] > 1:
            
            url = "https://oc.chengtou.oc.com:26335/rest/fault/v1/history-alarms/csns"
            now_date = datetime.datetime.now().strftime('%Y-%m-%d') + " 00:00:00"
            date_now = int(time.mktime(time.strptime(now_date, '%Y-%m-%d %H:%M:%S')) * 1000)
            body = {
                        "query": {
                        "filters": [{
                            "name": "OCCURUTC",
                            "field": "OCCURUTC",
                            "operator": ">=",
                            "values": [date_now]
                            }],
                        "express": "and"
                         },
                        "sort": [{
                        "field": "OCCURUTC",
                        "order": "desc"
                        }],
                        "size": 1000
            }
            response = self.easyrequest(uri=url, method='POST', data=body)
            finish_count = response["count"]
            # 获取当前告警数量
            url = "https://oc.chengtou.oc.com:26335/rest/fault/v1/current-alarms/csns"
            body = {
                        "query": {
                        "filters": [{
                            "name": "",
                            "field": "",
                            "operator": "",
                            "values": []
                            }],
                        "express": "and"
                         },
                        "sort": [{
                        "field": "",
                        "order": "desc"
                        }],
                        "size": 1000
            }

            alert_response = self.easyrequest(uri=url, method='POST', data=body)
            #处置的告警数
            deal_count = alert_response["count"]
            # 总的告警数
            count = finish_count + deal_count
            # 告警处置率
            deal_sum = finish_count/count
            sql4 = "update resource_ratio set value = {0} where name = 'error_resolve'".format(deal_sum)
            sql1 = "update alert_count set count = {0}, errortime = '{1}' where name = '待处置数' and errortime = '{2}'".format(deal_count,date, date7)
            sql2 = "update alert_count set count = {0}, errortime = '{1}'where name = '已处置数' and errortime = '{2}'".format(finish_count, date, date7)
            sql3 = "update alert_count set count = {0}, errortime = '{1}' where name = '告警数' and errortime = '{2}'".format(count, date, date7)
            sql_commands = ['delete from alert_info', sql1, sql2, sql3, sql4]
            for li in alert_response['csns']:
                uri = "https://oc.chengtou.oc.com:26335/rest/fault/v1/current-alarms?csns={}".format(li)
                li_response = self.easyrequest(uri=uri, method='GET', data={})
                print(li_response)
                if li_response[0]:
                    if li_response[0]["cleared"] == 1:
                        continue
                    else:
                        id = li_response[0]["csn"]
                        name = li_response[0]["alarmName"]
                        source = li_response[0]["meName"]
                        type = alert_dict[str(li_response[0]["severity"])]
                        tl = li_response[0]['occurUtc']/1000
                        tl = time.localtime(tl)
                        starttime = time.strftime("%m-%d %H:%M", tl)
                        sql = "insert into alert_info (id, name, source, starttime, type) values ({0}, '{1}', '{2}','{3}','{4}')".format(id, name, source, starttime, type)
                        sql_commands.append(sql)

            for sql in sql_commands:
                cur.execute(sql)
            conn.commit()
            conn.close()
        else:
            url = "https://oc.chengtou.oc.com:26335/rest/fault/v1/history-alarms/csns"
            now_date = datetime.datetime.now().strftime('%Y-%m-%d') + " 00:00:00"
            date_now = int(time.mktime(time.strptime(now_date, '%Y-%m-%d %H:%M:%S')) * 1000)
            body = {
                "query": {
                    "filters": [{
                        "name": "OCCURUTC",
                        "field": "OCCURUTC",
                        "operator": ">=",
                        "values": [date_now]
                    }],
                    "express": "and"
                },
                "sort": [{
                    "field": "OCCURUTC",
                    "order": "desc"
                }],
                "size": 1000
            }
            response = self.easyrequest(uri=url, method='POST', data=body)
            finish_count = response["count"]
            # 获取当前告警数量
            url = "https://oc.chengtou.oc.com:26335/rest/fault/v1/current-alarms/csns"
            body = {
                "query": {
                    "filters": [{
                        "name": "",
                        "field": "",
                        "operator": "",
                        "values": []
                    }],
                    "express": "and"
                },
                "sort": [{
                    "field": "",
                    "order": "desc"
                }],
                "size": 1000
            }

            alert_response = self.easyrequest(uri=url, method='POST', data=body)
            # 处置的告警数
            deal_count = alert_response["count"]
            # 总的告警数
            count = finish_count + deal_count
            # 告警处置率
            deal_sum = finish_count/count*100
            sql4 = "update resource_ratio set value = {0} where name = 'error_resolve'".format(deal_sum)
            sql1 = "update alert_count set count = {0} where name = '待处置数' and errortime = '{1}'".format(
                deal_count, date)
            sql2 = "update alert_count set count = {0} where name = '已处置数' and errortime = '{1}'".format(
                finish_count, date)
            sql3 = "update alert_count set count = {0} where name = '告警数' and errortime = '{1}'".format(
                count, date)
            sql_commands = ['delete from alert_info', sql1, sql2, sql3, sql4]
            for li in alert_response['csns']:
                uri = "https://oc.chengtou.oc.com:26335/rest/fault/v1/current-alarms?csns={}".format(li)
                li_response = self.easyrequest(uri=uri, method='GET', data={})
                if li_response[0]:
                    if li_response[0]["cleared"] == 1:
                        continue
                    else:
                        id = li_response[0]["csn"]
                        name = li_response[0]["alarmName"]
                        source = li_response[0]["meName"]
                        type = alert_dict[str(li_response[0]["severity"])]
                        tl = li_response[0]['occurUtc']/1000
                        tl = time.localtime(tl)
                        starttime = time.strftime("%m-%d %H:%M", tl)
                        sql = "insert into alert_info (id, name, source, starttime, type) values ({0}, '{1}', '{2}','{3}','{4}')".format(
                            id, name, source, starttime, type)
                        sql_commands.append(sql)

            for sql in sql_commands:

                cur.execute(sql)
            conn.commit()
            conn.close()


if __name__ == '__main__':
    # 获取token
    token = url_token()
    print(token)
    api = Api(token)
    # 获取总的cpu、memory、stage
    api.get_all()
    # 获取告警数据
    api.get_alert()

