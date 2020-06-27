//
//  JKCommunity.swift
//  JKCommunity
//
//  Created by 정진규 on 2020/06/21.
//

import Foundation
import JKFirebaseSDK
import JKExtension
import RxSwift
import RxCocoa
import RxOptional

public enum JKCommunityError: Error {
    case unknownError
    case readPostError
    case uploadImageError
    case insertPostError
}

fileprivate enum CommunityKeys: String {
    case user
    case post
    case comment
    
    case createdAt

    var key: String {
        return self.rawValue
    }
}

public class JKCommunity {
    public static let shared = JKCommunity()
    private init() {}

    private let firestore = FirebaseFirestore.shared
    private let firestorage = FirebaseStorage.shared

    public func insertPost(title: String, content: String, images: [UIImage]) -> Single<Result<DocumentKey, JKCommunityError>> {
        let userID = FirebaseAuthentication.shared.currentUser()?.uid ?? "EMPTY"

        let post = JKPost(id: "", title: title, content: content, userID: userID, createdAt: Date().toTimestamp(), updatedAt: nil, commentIDs: [], imageURLs: [])
    
        let insertPost = firestore.rx.insert(key: CommunityKeys.post.key, object: post, withID: true)
            .asObservable()
            .share()
        
        let insertPostValue = insertPost
            .filterMap { $0.value }
            .asObservable()

        let insertPostError = insertPost
            .filterMap { $0.error }
            .map { _ in Result<DocumentKey, JKCommunityError>.failure(.insertPostError) }
            .asObservable()

        let insertImageResult = insertPostValue
            .flatMapLatest { [weak self] postID -> Observable<Result<DocumentKey, JKCommunityError>> in
                guard let self = self else { return .just(Result<DocumentKey, JKCommunityError>.failure(.unknownError)) }
                guard images.isNotEmpty else { return .just(Result<DocumentKey, JKCommunityError>.success(postID)) }
                
                let insertImages = images.map { self.firestorage.rx.insertImage(path: "\(CommunityKeys.post.key)/\(postID)", image: $0).filterMap { $0.value }.asObservable() }

                let imageURLs = Observable.zip(insertImages).map { $0.map { $0.absoluteString } }

                let upsertDocumentResult = imageURLs
                    .flatMapLatest { imageURLs in
                        self.firestore.rx.upsertDocumentField(key: CommunityKeys.post.key, id: postID, data: ["imageURLs": imageURLs])
                    }
                    .share()

                let upsertDocumentValue = upsertDocumentResult
                    .filterMap { $0.value }
                    .map { _ in Result<DocumentKey, JKCommunityError>.success(postID) }
                    .asObservable()

                let upsertDocumentError = upsertDocumentResult
                    .filterMap { $0.error }
                    .map { _ in Result<DocumentKey, JKCommunityError>.failure(.uploadImageError) }
                    .asObservable()

                return Observable
                    .merge(
                        upsertDocumentValue,
                        upsertDocumentError
                    )
        }
        
        return Observable
            .merge(
                insertImageResult,
                insertPostError
            )
            .asSingle()
    }
    
    public func updatePost(post: JKPost, title: String? = nil, content: String? = nil) -> Single<Result<Void, FirestoreError>> {
        let updatedPost = JKPost(
            id: post.id,
            title: title ?? post.title,
            content: content ?? post.content,
            userID: post.userID,
            createdAt: post.createdAt,
            updatedAt: Date().toTimestamp(),
            commentIDs: post.commentIDs,
            imageURLs: post.imageURLs
        )

        return firestore.rx.update(key: CommunityKeys.post.key, id: post.id, object: updatedPost)
    }

    public func insertComment(postID: String, content: String) -> Single<Result<Void, FirestoreError>> {
        let userID = FirebaseAuthentication.shared.currentUser()?.uid ?? "EMPTY"

        let comment = JKComment(
            id: "",
            postID: postID,
            content: content,
            userID: userID,
            createdAt: Date().toTimestamp(),
            updatedAt: nil,
            imageURLs: []
        )

        let commentID = firestore.rx.insert(key: CommunityKeys.comment.key, object: comment, withID: true)
            .asObservable()
            .filterMap { $0.value }
        
        let post = firestore.rx.read(key: CommunityKeys.post.key, id: postID, type: JKPost.self)
            .asObservable()
            .filterMap { $0.value }

        return Observable
            .zip(post, commentID) { post, commentID -> [String] in
                var commentIDs = post.commentIDs
                commentIDs.append(commentID)
                return commentIDs
            }
            .flatMapLatest { [weak self] commentIDs -> Single<Result<Void, FirestoreError>> in
                return (self?.firestore.rx.upsertDocumentField(key: CommunityKeys.post.key, id: postID, data: ["commentIDs": commentIDs]) ?? .just(.failure(.defaultError("error add comment"))))
            }
            .asSingle()
    }

    public func deletePost(postID: String) -> Single<Result<Void, FirestoreError>> {
        let commentIDs = firestore.rx.read(key: CommunityKeys.post.key, id: postID, type: JKPost.self)
            .filterMap { $0.value }
            .map { $0.commentIDs }
            .asObservable()

        let deleteComments = commentIDs
            .map { [weak self] comments -> [Observable<Result<Void, FirestoreError>>] in
                return comments
                    .map { self?.firestore.rx.delete(key: CommunityKeys.comment.key, id: $0).asObservable() }
                    .compactMap { $0 }
            }
            .flatMapLatest { comments -> Observable<Result<Void, FirestoreError>> in
                return Observable.zip(comments).map { _ -> Result<Void, FirestoreError> in
                    return .success(Void())
                }
            }

        let deletePost = firestore.rx.delete(key: CommunityKeys.post.key, id: postID)
            .asObservable()

        return deleteComments.concat(deletePost).asSingle()
    }

    public func deleteComment(commentID: String) -> Single<Result<Void, FirestoreError>> {
        let postID = firestore.rx.read(key: CommunityKeys.comment.key, id: commentID, type: JKComment.self)
            .filterMap { $0.value }
            .map { $0.postID }
            .asObservable()

        let commentRefPost = postID
            .flatMapLatest { [weak self] in
                return (self?.firestore.rx.read(key: CommunityKeys.post.key, id: $0, type: JKPost.self).asObservable()) ?? .just(.failure(.defaultError("error add comment")))
            }
            .filterMap { $0.value }
        
        let deleteCommentRefPost = commentRefPost
            .flatMapLatest { [weak self] post -> Observable<Result<Void, FirestoreError>> in
                let updatedCommentIDs = post.commentIDs.filter { $0 != commentID }
                return (self?.firestore.rx.upsertDocumentField(key: CommunityKeys.post.key, id: post.id, data: ["commentIDs": updatedCommentIDs]).asObservable()) ?? .just(.failure(.defaultError("error delete comment")))
            }
        
        let deleteComment = firestore.rx.delete(key: CommunityKeys.comment.key, id: commentID)

        return deleteCommentRefPost.concat(deleteComment).asSingle()
    }
    
    public func getPosts(limit: Int, latestPostID: String?) -> Single<Result<[JKPost], JKCommunityError>> {
        let postResult = firestore.rx.list(key: CommunityKeys.post.key, orderBy: [QueryOrder(key: CommunityKeys.createdAt.key, isDescending: true)], limit: limit, latestKey: latestPostID, type: JKPost.self)

        let postValue = postResult
            .filterMap { $0.value }
            .map { Result<[JKPost], JKCommunityError>.success($0) }
            .asObservable()

        let postError = postResult
            .filterMap { $0.error }
            .mapVoid()
            .map { Result<[JKPost], JKCommunityError>.failure(.readPostError) }
            .asObservable()

        return Observable
            .merge(postValue, postError)
            .asSingle()
    }

    public func getComments(commentIDs: [String]) -> Single<Result<[JKComment], FirestoreError>> {
        let commentObservablesResult = commentIDs.map { firestore.rx.read(key: CommunityKeys.comment.key, id: $0, type: JKComment.self).filterMap { $0 }.asObservable() }
        
        return Observable
            .zip(commentObservablesResult)
            .filterMap { $0.compactMap { $0.value } }
            .map { $0.sorted { (lComment, rComment) -> Bool in
                return lComment.createdAt <= rComment.createdAt
            }}
            .map { Result<[JKComment], FirestoreError>.success($0) }
            .catchErrorJustReturn(Result<[JKComment], FirestoreError>.failure(.defaultError("cannot read commnets")))
            .asSingle()
    }
}
