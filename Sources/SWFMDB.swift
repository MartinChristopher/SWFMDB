//
//  SWFMDB.swift
//

import FMDB
import UIKit

let kPrimaryKeyName  = "primaryKeyName"
let kPrimaryKeyType  = "primaryKeyType"
let kPropertyTypeDic = "propertyTypeDic"

public class SWFMDB: NSObject {
    
    public static let shared = SWFMDB()
    
    private var db: FMDatabase!
    
    public override init() {
        super.init()
        let dbPath = SWFMDBUtil.dbPathForName("SWFMDB.sqlite")
        print(dbPath)
        db = FMDatabase(path: dbPath)
        guard db.open() else {
            fatalError("Could not open database at path")
        }
    }
    
}

public extension SWFMDB {
    // 判断表
    func isExistTable(_ tableName: String) -> Bool {
        guard let set = db.executeQuery("SELECT count(*) as 'count' FROM sqlite_master WHERE type ='table' and name = ?", withArgumentsIn: [tableName]) else {
            return false
        }
        while set.next() {
            let count = set.int(forColumn: "count")
            if count == 0 {
                return false
            } else {
                return true
            }
        }
        return false
    }
    // 创建表
    func createWithTable(_ tableName: String,
                         metaType: Any,
                         excludeName nameArray: [String]? = nil,
                         primaryKeyDic: [String: String]? = nil) -> Bool {
        var result = false
        let dic = SWFMDBUtil.storageTypeToDictionary(metaType)
        let userDefault = UserDefaults.standard
        var propertyTypeDic = userDefault.dictionary(forKey: kPropertyTypeDic) ?? [:]
        guard let dbPath = db.databasePath else {
            return false
        }
        var typeDic = propertyTypeDic[SWFMDBUtil.getFileName(dbPath)] as? [String: Any] ?? [:]
        typeDic[tableName] = dic
        propertyTypeDic[SWFMDBUtil.getFileName(dbPath)] = typeDic
        userDefault.set(propertyTypeDic, forKey: kPropertyTypeDic)
        userDefault.synchronize()
        var sql = "CREATE TABLE IF NOT EXISTS \(tableName) ("
        var keyCount = 0
        for (key, value) in dic {
            keyCount += 1
            if let primaryKey = primaryKeyDic, key == primaryKey[kPrimaryKeyName] {
                if keyCount == dic.count {
                    sql.append("\(primaryKey[kPrimaryKeyName]!) \(primaryKey[kPrimaryKeyType]!) PRIMARY KEY)")
                    break
                } else {
                    sql.append("\(primaryKey[kPrimaryKeyName]!) \(primaryKey[kPrimaryKeyType]!) PRIMARY KEY,")
                    continue
                }
            }
            if let excludeNames = nameArray, excludeNames.contains(key) {
                if keyCount == dic.count {
                    sql.remove(at: sql.index(before: sql.endIndex))
                    sql.append(")")
                    break
                }
                continue
            }
            if keyCount == dic.count {
                sql.append(" \(key) \(value))")
                break
            }
            sql.append(" \(key) \(value),")
        }
        result = db.executeStatements(sql)
        return result
    }
    // 清空表
    func clearWithTable(_ tableName: String) -> Bool {
        var result = false
        let sql = "DELETE FROM \(tableName)"
        do {
            try db.executeUpdate(sql, values: nil)
            result = true
            print("清空成功")
        } catch {
            print("清空失败: \(error)")
        }
        return result
    }
    // 插入多条数据
    func addWithTable(_ tableName: String, dataSource: [Any]) {
        let columnArray = getColumnArray(tableName)
        let userDefault = UserDefaults.standard
        let propertyTypeDic = userDefault.dictionary(forKey: kPropertyTypeDic) ?? [:]
        guard let dbPath = db.databasePath else { return }
        let typeDic = propertyTypeDic[SWFMDBUtil.getFileName(dbPath)] as? [String: Any] ?? [:]
        let dbDic = typeDic[tableName] as? [String: Any] ?? [:]
        for data in dataSource {
            let _ = insertWithTable(tableName, model: data, columnArray: columnArray, propertyTypeDic: dbDic)
        }
    }
    // 插入单条数据
    func insertWithTable(_ tableName: String, model: Any) -> Bool {
        let columnArray = getColumnArray(tableName)
        let userDefault = UserDefaults.standard
        let propertyTypeDic = userDefault.dictionary(forKey: kPropertyTypeDic) ?? [:]
        guard let dbPath = db.databasePath else {
            return false
        }
        let typeDic = propertyTypeDic[SWFMDBUtil.getFileName(dbPath)] as? [String: Any] ?? [:]
        let dbDic = typeDic[tableName] as? [String: Any] ?? [:]
        return insertWithTable(tableName, model: model, columnArray: columnArray, propertyTypeDic: dbDic)
    }
    
    private func insertWithTable(_ tableName: String,
                                 model: Any,
                                 columnArray: [String],
                                 propertyTypeDic: [String: Any]) -> Bool {
        var dic = [String: Any]()
        if let modelDataSource = model as? NSObject {
            dic = SWFMDBUtil.getModelPropertyKeyValue(modelDataSource, columnArray: columnArray)
        }
        var sql = "INSERT INTO \(tableName) ("
        var tempStr = ""
        var argumentsArray = [Any]()
        for key in dic.keys {
            if !columnArray.contains(key) {
                continue
            }
            sql.append("\(key),")
            tempStr.append("?,")
            if propertyTypeDic[key] as? String == SQL_ARRAY {
                argumentsArray.append(NSKeyedArchiver.archivedData(withRootObject: dic[key] as Any))
            } else if propertyTypeDic[key] as? String == SQL_MODEL {
                argumentsArray.append(NSKeyedArchiver.archivedData(withRootObject: dic[key] as Any))
            } else {
                argumentsArray.append(dic[key] as Any)
            }
        }
        // 删除最后一个符号
        sql.removeLast()
        // 删除最后一个符号
        if !tempStr.isEmpty {
            tempStr.removeLast()
        }
        sql.append(") VALUES (\(tempStr))")
        let result = db.executeUpdate(sql, withArgumentsIn: argumentsArray)
        if result {
            print("插入成功")
        } else {
            print("插入失败")
        }
        return result
    }
    // 删除数据
    func deleteWithTable(_ tableName: String, whereFormat: String) -> Bool {
        var result = false
        let sql = "DELETE FROM \(tableName) \(whereFormat)"
        do {
            try db.executeUpdate(sql, values: nil)
            result = true
            print("删除成功")
        } catch {
            print("删除失败: \(error)")
        }
        return result
    }
    // 修改数据
    func updateWithTable(_ tableName: String, 
                         model: Any,
                         whereFormat: String) -> Bool {
        var result = false
        var sql = "UPDATE \(tableName) SET "
        var dic = [String: Any]()
        let columnArray = getColumnArray(tableName)
        dic = SWFMDBUtil.getModelPropertyKeyValue(model, columnArray: columnArray)
        let userDefault = UserDefaults.standard
        let propertyTypeDic = userDefault.dictionary(forKey: kPropertyTypeDic) ?? [:]
        guard let dbPath = db.databasePath else {
            return false
        }
        let typeDic = propertyTypeDic[SWFMDBUtil.getFileName(dbPath)] as? [String: Any] ?? [:]
        let dbDic = typeDic[tableName] as? [String: Any] ?? [:]
        var argumentsArray = [Any]()
        for (key, value) in dic {
            if !columnArray.contains(key) {
                continue
            }
            sql.append("\(key) = ?,")
            if dbDic[key] as! String == SQL_ARRAY {
                argumentsArray.append(NSKeyedArchiver.archivedData(withRootObject: value))
            } else if dbDic[key] as! String == SQL_MODEL {
                argumentsArray.append(NSKeyedArchiver.archivedData(withRootObject: value))
            } else {
                argumentsArray.append(value)
            }
        }
        sql.removeLast()
        if !whereFormat.isEmpty {
            sql.append(" \(whereFormat)")
        }
        result = db.executeUpdate(sql, withArgumentsIn: argumentsArray)
        if result {
            print("修改成功")
        } else {
            print("修改失败")
        }
        return result
    }
    // 查询数据
    func selectWithTable(_ tableName: String,
                         metaType: Any,
                         whereFormat format: String?) -> [Any] {
        let sql = "SELECT * FROM \(tableName) \(format ?? "")"
        guard let set = db.executeQuery(sql, withArgumentsIn: []) else {
            return []
        }
        var resultArray = [Any]()
        var columnArray = [String]()
        var cls: AnyClass?
        cls = SWFMDBUtil.getModelClass(metaType)
        let userDefault = UserDefaults.standard
        let propertyTypeDic = userDefault.dictionary(forKey: kPropertyTypeDic) ?? [:]
        guard let dbPath = db.databasePath else {
            return []
        }
        let typeDic = propertyTypeDic[SWFMDBUtil.getFileName(dbPath)] as? [String: Any] ?? [:]
        let dbDic = typeDic[tableName] as? [String: Any] ?? [:]
        columnArray = getColumnArray(tableName)
        if let cls = cls {
            while set.next() {
                guard let resultObject = (cls as? NSObject.Type)?.init() else {
                    continue
                }
                for name in columnArray {
                    if dbDic[name] as! String == SQL_TEXT {
                        if let value = set.string(forColumn: name) {
                            resultObject.setValue(value, forKey: name)
                        }
                    } else if dbDic[name] as! String == SQL_INTEGER {
                        resultObject.setValue(NSNumber(value: set.longLongInt(forColumn: name)), forKey: name)
                    } else if dbDic[name] as! String == SQL_REAL {
                        resultObject.setValue(NSNumber(value: set.double(forColumn: name)), forKey: name)
                    } else if dbDic[name] as! String == SQL_BLOB {
                        if let value = set.data(forColumn: name) {
                            resultObject.setValue(value, forKey: name)
                        }
                    } else if dbDic[name] as! String == SQL_ARRAY {
                        if let data = set.data(forColumn: name),
                            let array = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [Any] {
                            resultObject.setValue(array, forKey: name)
                        }
                    } else if dbDic[name] as! String == SQL_MODEL {
                        if let data = set.data(forColumn: name),
                            let model = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? NSObject {
                            resultObject.setValue(model, forKey: name)
                        }
                    }
                }
                resultArray.append(resultObject)
            }
        }
        return resultArray
    }
    // 获取字段
    private func getColumnArray(_ tableName: String) -> [String] {
        var array = [String]()
        guard let resultSet = db.getTableSchema("\(tableName)") else {
            return array
        }
        while resultSet.next() {
            if let columnName = resultSet.string(forColumn: "name") {
                array.append(columnName)
            }
        }
        return array
    }
    
}
