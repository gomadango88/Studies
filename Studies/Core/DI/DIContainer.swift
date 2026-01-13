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
    
    private init() {
   
    }
    
    // MARK: - SwiftData
    var modelContainer: ModelContainer {
        if _modelContainer == nil {
                        
            let schema = Schema([
                SubjectModel.self,
                StudyRecordModel.self,
                DailyAchievementModel.self
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            
            do {
                _modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
                print("ModelContainer created successfully")
            } catch {
                
                let fallbackSchema = Schema([])
                _modelContainer = try! ModelContainer(for: fallbackSchema)
                print("ModelContainer initialization failed: \(error)")
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

