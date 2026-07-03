//
//  DIContainer.swift
//  Studies
//
//  Created by kasahara takuma on 2025/08/08.
//



import Foundation
import SwiftData
import SwiftUI

@Observable
class DIContainer {
    static let shared = DIContainer()

    private var _modelContainer: ModelContainer?

    // 永続ストアの作成に失敗し、インメモリストアへフォールバックした場合にtrueになる。
    // ContentView側でこのフラグを見て、ユーザーに一度だけ注意喚起のアラートを表示する。
    var isPersistentStoreUnavailable: Bool = false

    private init() {

    }

    // MARK: - SwiftData
    var modelContainer: ModelContainer {
        if _modelContainer == nil {

            let schema = Schema([
                SubjectModel.self,
                StudyRecordModel.self,
                DailyAchievementModel.self,
                StudyScheduleModel.self,
                SubjectGoalModel.self
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )

            do {
                _modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
                print("ModelContainer created successfully")
            } catch {
                // 永続ストアの作成に失敗した場合でも、同じスキーマのインメモリストアに
                // フォールバックすることで、以後の全fetch/insertがクラッシュするのを防ぐ
                print("ModelContainer initialization failed, falling back to in-memory store: \(error)")
                isPersistentStoreUnavailable = true
                let inMemoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                do {
                    _modelContainer = try ModelContainer(for: schema, configurations: [inMemoryConfiguration])
                } catch {
                    // インメモリストアの作成にすら失敗する場合は、アプリとして継続不能な致命的な状態。
                    // 原因を明示した上でクラッシュさせ、サイレントな不整合状態を避ける。
                    fatalError("インメモリのModelContainer作成にも失敗しました。デバイスのメモリ不足など回復不能な問題が疑われます: \(error)")
                }
            }
        }
        return _modelContainer!
    }
    
    // MARK: - Repositories
    private var _subjectRepository: SubjectRepositoryProtocol?
    var subjectRepository: SubjectRepositoryProtocol {
        if _subjectRepository == nil {
            _subjectRepository = SubjectRepository(modelContainer: modelContainer)
        }
        return _subjectRepository!
    }
    
    private var _studyRecordRepository: StudyRecordRepositoryProtocol?
    var studyRecordRepository: StudyRecordRepositoryProtocol {
        if _studyRecordRepository == nil {
            _studyRecordRepository = StudyRecordRepository(modelContainer: modelContainer)
        }
        return _studyRecordRepository!
    }
    
    private var _scheduleRepository: ScheduleRepositoryProtocol?
    var scheduleRepository: ScheduleRepositoryProtocol {
        if _scheduleRepository == nil {
            _scheduleRepository = ScheduleRepository(modelContainer: modelContainer)
        }
        return _scheduleRepository!
    }
    
    // MARK: - Use Cases
    private var _subjectUseCase: SubjectUseCaseProtocol?
    var subjectUseCase: SubjectUseCaseProtocol {
        if _subjectUseCase == nil {
            _subjectUseCase = SubjectUseCase(repository: subjectRepository)
        }
        return _subjectUseCase!
    }
    
    private var _studyRecordUseCase: StudyRecordUseCaseProtocol?
    var studyRecordUseCase: StudyRecordUseCaseProtocol {
        if _studyRecordUseCase == nil {
            _studyRecordUseCase = StudyRecordUseCase(
                studyRecordRepository: studyRecordRepository,
                subjectRepository: subjectRepository
            )
        }
        return _studyRecordUseCase!
    }
}

