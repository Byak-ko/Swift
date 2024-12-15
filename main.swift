import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct Video: Decodable {
    let title: String
    let views: Int
    let url: String
}

struct YouTubeSearchResponse: Decodable {
    struct Item: Decodable {
        struct Snippet: Decodable {
            let title: String
        }
        let id: VideoId
        let snippet: Snippet
    }
    
    struct VideoId: Decodable {
        let videoId: String
    }
    
    let items: [Item]
}

struct YouTubeVideoResponse: Decodable {
    struct Item: Decodable {
        struct Statistics: Decodable {
            let viewCount: String
        }
        let id: String
        let statistics: Statistics
    }
    
    let items: [Item]
}

func fetchYouTubeVideos(for searchQuery: String, completion: @escaping ([Video]) -> Void) {
    let apiKey = "AIzaSyDOB3n8PzsspFels4enGVhdkk6JZbct514"
    let maxResults = 10
    
    let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchQuery
    let searchURLString = "https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=\(maxResults)&q=\(encodedQuery)&type=video&key=\(apiKey)"
    
    guard let searchURL = URL(string: searchURLString) else {
        print("Неправильна URL-адреса")
        return
    }
    
    let session = URLSession.shared
    
    session.dataTask(with: searchURL) { data, response, error in
        if let error = error {
            print("Помилка запиту: \(error.localizedDescription)")
            return
        }
        
        guard let data = data else {
            print("Немає даних")
            return
        }
        
        do {
            let searchResponse = try JSONDecoder().decode(YouTubeSearchResponse.self, from: data)
            let videoIds = searchResponse.items.map { $0.id.videoId }.joined(separator: ",")
            
            let videoDetailsURLString = "https://www.googleapis.com/youtube/v3/videos?part=statistics&id=\(videoIds)&key=\(apiKey)"
            
            guard let videoDetailsURL = URL(string: videoDetailsURLString) else {
                print("Неправильна URL-адреса для деталей відео")
                return
            }
            
            session.dataTask(with: videoDetailsURL) { data, response, error in
                if let error = error {
                    print("Помилка запиту деталей відео: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    print("Немає даних для деталей відео")
                    return
                }
                
                do {
                    let videoDetailsResponse = try JSONDecoder().decode(YouTubeVideoResponse.self, from: data)
                    var videos: [Video] = []
                    
                    for item in searchResponse.items {
                        let videoId = item.id.videoId
                        let videoUrl = "https://www.youtube.com/watch?v=\(videoId)"
                        if let statistics = videoDetailsResponse.items.first(where: { $0.id == videoId })?.statistics,
                           let viewCount = Int(statistics.viewCount) {
                            let video = Video(title: item.snippet.title, views: viewCount, url: videoUrl)
                            videos.append(video)
                        } else {
                            let video = Video(title: item.snippet.title, views: 0, url: videoUrl)
                            videos.append(video)
                        }
                    }
                    
                    completion(videos)
                } catch {
                    print("Помилка декодування JSON деталей відео: \(error)")
                }
            }.resume()
        } catch {
            print("Помилка декодування JSON: \(error)")
        }
    }.resume()
}

func printVideos(_ videos: [Video]) {
    if videos.isEmpty {
        print("Немає доступних відео.")
    } else {
        for (index, video) in videos.enumerated() {
            print("\(index + 1). Назва: \(video.title), Перегляди: \(video.views), Посилання: \(video.url)")
        }
    }
}

func searchVideos(by title: String, in videos: [Video]) -> [Video] {
    return videos.filter { $0.title.range(of: title, options: .caseInsensitive) != nil }
}

func main() {
    print("Введіть пошуковий запит для YouTube:")
    if let searchQuery = readLine(), !searchQuery.isEmpty {
        print("Завантаження відео за запитом: \(searchQuery)")
        fetchYouTubeVideos(for: searchQuery) { videos in
            let sortedVideos = videos.sorted { $0.views > $1.views }
            print("\nСписок відео:")
            printVideos(sortedVideos)
        }
    } else {
        print("Пошуковий запит не може бути порожнім.")
    }
}

main()

RunLoop.main.run()
