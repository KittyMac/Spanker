import XCTest
import class Foundation.Bundle

import Spanker

class SpankerTests: TestsBase {
    
    func test_empty_array() {
        let json = #"[]"#
        json.parsed { result in
            XCTAssertEqual(json, result?.description)
        }
    }
    
    func test_empty_object() {
        let json = #"{}"#
        json.parsed { result in
            XCTAssertEqual(json, result?.description)
        }
    }
    
    func test_array_numbers0() {
        let json = #"[0,1,2,3]"#
        json.parsed { result in
            XCTAssertEqual(json, result?.description)
        }
    }
    
    func test_array_numbers1() {
        let json = #"[0.5,1.2,2.7,3.7556367]"#
        json.parsed { result in
            XCTAssertEqual(json, result?.description)
        }
    }
    
    func test_array_strings0() {
            let json = #"["A","B","C"]"#
        json.parsed { result in
            XCTAssertEqual(json, result?.description)
        }
        }
    
    func test_object_simple0() {
        let json = #"{"foo":"bar"}"#
        json.parsed { result in
            XCTAssertEqual(json, result?.description)
        }
    }
    
    func test_object_simple1() {
        let json = #"{"foo":{"bar":"baz"}}"#
        json.parsed { result in
            XCTAssertEqual(json, result?.description)
        }
    }
    
    func test_array_objects_simple1() {
        let json = #"[{"foo":{"bar":"baz"}},{"foo":{"bar":"baz"}},{"foo":{"bar":"baz"}},{"foo":{"bar":"baz"}},{"foo":{"bar":"baz"}},{"foo":{"bar":"baz"}}]"#
        json.parsed { result in
            XCTAssertEqual(json, result?.description)
        }
    }
    
    func test_object_simple2() {
        let json = "{\"int-max-property\":\(UINT32_MAX),\"long-max-property\":\(LLONG_MAX)}"
        json.parsed { result in
            XCTAssertEqual(json, result?.description)
        }
    }
    
    func test_object_simple3() {
        let json = #"[{"category":"reference","author":"Nigel Rees","title":"Sayings of the Century","display-price":8.95},{"category":"fiction","author":"Evelyn Waugh","title":"Sword of Honour","display-price":12.99},{"category":"fiction","author":"Herman Melville","title":"Moby Dick","isbn":"0-553-21311-3","display-price":8.99},{"category":"fiction","author":"J. R. R. Tolkien","title":"The Lord of the Rings","isbn":"0-395-19395-8","display-price":22.99}]"#
        json.parsed { result in
            XCTAssertEqual(json, result?.description)
        }
    }
    
    func test_object_simple4() {
            let json = #"{"store":{"book":[{"category":"reference","author":"Nigel Rees","title":"Sayings of the Century","price":8.95,"address":{"street":"fleet street","city":"London"}},{"category":"fiction","author":"Evelyn Waugh","title":"Sword of Honour","price":12.9,"address":{"street":"Baker street","city":"London"}},{"category":"fiction","author":"J. R. R. Tolkien","title":"The Lord of the Rings","isbn":"0-395-19395-8","price":22.99,"address":{"street":"Svea gatan","city":"Stockholm"}}],"bicycle":{"color":"red","price":19.95,"address":{"street":"Söder gatan","city":"Stockholm"},"items":[["A","B","C"],1,2,3,4,5]}}}"#
        json.parsed { result in
            XCTAssertEqual(json, result?.description)
        }
    }
    
    func test_object_simple5() {
        let json = #"["{}[]","{}[]","{}[]","{}[]"]"#
        json.parsed { result in
            XCTAssertEqual(json, result?.description)
        }
    }
    
    func test_object_simple6() {
        let json = #"{"key0":"{}[]","key1":"{}[]","key2":"{}[]","key3":"{}[]"}"#
        json.parsed { result in
            XCTAssertEqual(json, result?.description)
        }
    }
    
    func test_boolean() {
        let jsons = [
            #"true"#,
            #"false"#,
            #"[true]"#,
            #"[false]"#,
        ]
        for json in jsons {
            json.parsed { result in
                XCTAssertEqual(json, result?.description)
            }
        }
    }
    
    func test_int() {
        let jsons = [
            #"0"#,
            #"1245678"#,
            #"-1245678"#,
            #"[0]"#,
            #"[1245678]"#,
            #"[-1245678]"#
        ]
        for json in jsons {
            json.parsed { result in
                XCTAssertEqual(json, result?.description)
            }
        }
    }
    
    func test_double() {
        let jsons = [
            #"0.0"#,
            #"0"#,
            #"1245678.2642348"#,
            #"-1245678.2397824"#,
            #"[0.0]"#,
            #"[0]"#,
            #"[1245678.2642348]"#,
            #"[-1245678.2397824]"#
        ]
        for json in jsons {
            json.parsed { result in
                XCTAssertEqual(json, result?.description)
            }
        }
    }
    
    func test_string() {
        let json = #""hello world""#
        json.parsed { result in
            XCTAssertEqual(json, result?.description)
        }
    }
    
    func test_github0() {
        let json = #"[{"id":"2489651045","type":"CreateEvent","actor":{"id":665991,"login":"petroav","gravatar_id":"","url":"https://api.github.com/users/petroav","avatar_url":"https://avatars.githubusercontent.com/u/665991?"},"repo":{"id":28688495,"name":"petroav/6.828","url":"https://api.github.com/repos/petroav/6.828"},"payload":{"ref":"master","ref_type":"branch","master_branch":"master","description":"Solution to homework and assignments from MIT's 6.828 (Operating Systems Engineering). Done in my spare time.","pusher_type":"user"},"public":true,"created_at":"2015-01-01T15:00:00Z"},{"id":"2489651051","type":"PushEvent","actor":{"id":3854017,"login":"rspt","gravatar_id":"","url":"https://api.github.com/users/rspt","avatar_url":"https://avatars.githubusercontent.com/u/3854017?"},"repo":{"id":28671719,"name":"rspt/rspt-theme","url":"https://api.github.com/repos/rspt/rspt-theme"},"payload":{"push_id":536863970,"size":1,"distinct_size":1,"ref":"refs/heads/master","head":"6b089eb4a43f728f0a594388092f480f2ecacfcd","before":"437c03652caa0bc4a7554b18d5c0a394c2f3d326","commits":[{"sha":"6b089eb4a43f728f0a594388092f480f2ecacfcd","author":{"email":"5c682c2d1ec4073e277f9ba9f4bdf07e5794dabe@rspt.ch","name":"rspt"},"message":"Fix main header height on mobile","distinct":true,"url":"https://api.github.com/repos/rspt/rspt-theme/commits/6b089eb4a43f728f0a594388092f480f2ecacfcd"}]},"public":true,"created_at":"2015-01-01T15:00:01Z"},{"id":"2489651570","type":"IssueCommentEvent","actor":{"id":7194491,"login":"BackSlasher","gravatar_id":"","url":"https://api.github.com/users/BackSlasher","avatar_url":"https://avatars.githubusercontent.com/u/7194491?"},"repo":{"id":4056288,"name":"opscode/omnibus-chef","url":"https://api.github.com/repos/opscode/omnibus-chef"},"payload":{"action":"created","issue":{"url":"https://api.github.com/repos/opscode/omnibus-chef/issues/319","labels_url":"https://api.github.com/repos/opscode/omnibus-chef/issues/319/labels{/name}","comments_url":"https://api.github.com/repos/opscode/omnibus-chef/issues/319/comments","events_url":"https://api.github.com/repos/opscode/omnibus-chef/issues/319/events","html_url":"https://github.com/opscode/omnibus-chef/issues/319","id":53215487,"number":319,"title":"Symbolic links for knife etc conflict when installing ChefDK and Chef Client","user":{"login":"BackSlasher","id":7194491,"avatar_url":"https://avatars.githubusercontent.com/u/7194491?v=3","gravatar_id":"","url":"https://api.github.com/users/BackSlasher","html_url":"https://github.com/BackSlasher","followers_url":"https://api.github.com/users/BackSlasher/followers","following_url":"https://api.github.com/users/BackSlasher/following{/other_user}","gists_url":"https://api.github.com/users/BackSlasher/gists{/gist_id}","starred_url":"https://api.github.com/users/BackSlasher/starred{/owner}{/repo}","subscriptions_url":"https://api.github.com/users/BackSlasher/subscriptions","organizations_url":"https://api.github.com/users/BackSlasher/orgs","repos_url":"https://api.github.com/users/BackSlasher/repos","events_url":"https://api.github.com/users/BackSlasher/events{/privacy}","received_events_url":"https://api.github.com/users/BackSlasher/received_events","type":"User","site_admin":false},"labels":[],"state":"closed","locked":false,"assignee":null,"milestone":null,"comments":2,"created_at":"2015-01-01T08:15:03Z","updated_at":"2015-01-01T15:01:02Z","closed_at":"2015-01-01T14:31:08Z","body":"When running Ubuntu 14.04, After installing the following in that order:\r\n* Chef client latest (12.0.3-1)\r\n* ChefDK latest (0.3.5)\r\n\r\nAnd running `knife --version`, I get version 11.  \r\nThis is an issue because after installing ChefDK, I was unable to bootstrap Chef 12 clients (because Knife 11 wouldn't copy self-signed certificates like Knife 12 does).\r\n\r\nThis is because both packages include knife, and each is overwriting `/usr/bin/knife`, meaning the last installed product \"wins\".\r\nInstead of using [`ln -sf`](https://github.com/opscode/omnibus-chef/blob/master/package-scripts/chefdk/postinst#L39), one could use [Debian alternatives](https://www.debian-administration.org/article/91/Using_the_Debian_alternatives_system), allowing both Knife versions from ChefDK and Chef Client to coexist.\r\nOr one can avoid overwriting the link if it points to a newer version."},"comment":{"url":"https://api.github.com/repos/opscode/omnibus-chef/issues/comments/68488509","html_url":"https://github.com/opscode/omnibus-chef/issues/319#issuecomment-68488509","issue_url":"https://api.github.com/repos/opscode/omnibus-chef/issues/319","id":68488509,"user":{"login":"BackSlasher","id":7194491,"avatar_url":"https://avatars.githubusercontent.com/u/7194491?v=3","gravatar_id":"","url":"https://api.github.com/users/BackSlasher","html_url":"https://github.com/BackSlasher","followers_url":"https://api.github.com/users/BackSlasher/followers","following_url":"https://api.github.com/users/BackSlasher/following{/other_user}","gists_url":"https://api.github.com/users/BackSlasher/gists{/gist_id}","starred_url":"https://api.github.com/users/BackSlasher/starred{/owner}{/repo}","subscriptions_url":"https://api.github.com/users/BackSlasher/subscriptions","organizations_url":"https://api.github.com/users/BackSlasher/orgs","repos_url":"https://api.github.com/users/BackSlasher/repos","events_url":"https://api.github.com/users/BackSlasher/events{/privacy}","received_events_url":"https://api.github.com/users/BackSlasher/received_events","type":"User","site_admin":false},"created_at":"2015-01-01T15:01:02Z","updated_at":"2015-01-01T15:01:02Z","body":"@lamont-granquist I think this issue will reoccur the next time there's a functional difference between the latest client and the latest DK. Don't you think the installation script should at least print an error when there's an existing (and valid) symlink?\r\n\r\nI'll be happy to help, I just want to get your idea of what's a good solution before I work on it."}},"public":true,"created_at":"2015-01-01T15:01:02Z","org":{"id":29740,"login":"opscode","gravatar_id":"","url":"https://api.github.com/orgs/opscode","avatar_url":"https://avatars.githubusercontent.com/u/29740?"}},{"id":"2489651570","type":"IssueCommentEvent","actor":{"id":7194491,"login":"BackSlasher","gravatar_id":"","url":"https://api.github.com/users/BackSlasher","avatar_url":"https://avatars.githubusercontent.com/u/7194491?"},"repo":{"id":4056288,"name":"opscode/omnibus-chef","url":"https://api.github.com/repos/opscode/omnibus-chef"},"payload":{"action":"created","issue":{"url":"https://api.github.com/repos/opscode/omnibus-chef/issues/319","labels_url":"https://api.github.com/repos/opscode/omnibus-chef/issues/319/labels{/name}","comments_url":"https://api.github.com/repos/opscode/omnibus-chef/issues/319/comments","events_url":"https://api.github.com/repos/opscode/omnibus-chef/issues/319/events","html_url":"https://github.com/opscode/omnibus-chef/issues/319","id":53215487,"number":319,"title":"Symbolic links for knife etc conflict when installing ChefDK and Chef Client","user":{"login":"BackSlasher","id":7194491,"avatar_url":"https://avatars.githubusercontent.com/u/7194491?v=3","gravatar_id":"","url":"https://api.github.com/users/BackSlasher","html_url":"https://github.com/BackSlasher","followers_url":"https://api.github.com/users/BackSlasher/followers","following_url":"https://api.github.com/users/BackSlasher/following{/other_user}","gists_url":"https://api.github.com/users/BackSlasher/gists{/gist_id}","starred_url":"https://api.github.com/users/BackSlasher/starred{/owner}{/repo}","subscriptions_url":"https://api.github.com/users/BackSlasher/subscriptions","organizations_url":"https://api.github.com/users/BackSlasher/orgs","repos_url":"https://api.github.com/users/BackSlasher/repos","events_url":"https://api.github.com/users/BackSlasher/events{/privacy}","received_events_url":"https://api.github.com/users/BackSlasher/received_events","type":"User","site_admin":false},"labels":[],"state":"closed","locked":false,"assignee":null,"milestone":null,"comments":2,"created_at":"2015-01-01T08:15:03Z","updated_at":"2015-01-01T15:01:02Z","closed_at":"2015-01-01T14:31:08Z","body":"When running Ubuntu 14.04, After installing the following in that order:\r\n* Chef client latest (12.0.3-1)\r\n* ChefDK latest (0.3.5)\r\n\r\nAnd running `knife --version`, I get version 11.  \r\nThis is an issue because after installing ChefDK, I was unable to bootstrap Chef 12 clients (because Knife 11 wouldn't copy self-signed certificates like Knife 12 does).\r\n\r\nThis is because both packages include knife, and each is overwriting `/usr/bin/knife`, meaning the last installed product \"wins\".\r\nInstead of using [`ln -sf`](https://github.com/opscode/omnibus-chef/blob/master/package-scripts/chefdk/postinst#L39), one could use [Debian alternatives](https://www.debian-administration.org/article/91/Using_the_Debian_alternatives_system), allowing both Knife versions from ChefDK and Chef Client to coexist.\r\nOr one can avoid overwriting the link if it points to a newer version."},"comment":{"url":"https://api.github.com/repos/opscode/omnibus-chef/issues/comments/68488509","html_url":"https://github.com/opscode/omnibus-chef/issues/319#issuecomment-68488509","issue_url":"https://api.github.com/repos/opscode/omnibus-chef/issues/319","id":68488509,"user":{"login":"BackSlasher","id":7194491,"avatar_url":"https://avatars.githubusercontent.com/u/7194491?v=3","gravatar_id":"","url":"https://api.github.com/users/BackSlasher","html_url":"https://github.com/BackSlasher","followers_url":"https://api.github.com/users/BackSlasher/followers","following_url":"https://api.github.com/users/BackSlasher/following{/other_user}","gists_url":"https://api.github.com/users/BackSlasher/gists{/gist_id}","starred_url":"https://api.github.com/users/BackSlasher/starred{/owner}{/repo}","subscriptions_url":"https://api.github.com/users/BackSlasher/subscriptions","organizations_url":"https://api.github.com/users/BackSlasher/orgs","repos_url":"https://api.github.com/users/BackSlasher/repos","events_url":"https://api.github.com/users/BackSlasher/events{/privacy}","received_events_url":"https://api.github.com/users/BackSlasher/received_events","type":"User","site_admin":false},"created_at":"2015-01-01T15:01:02Z","updated_at":"2015-01-01T15:01:02Z","body":"@lamont-granquist I think this issue will reoccur the next time there's a functional difference between the latest client and the latest DK. Don't you think the installation script should at least print an error when there's an existing (and valid) symlink?\r\n\r\nI'll be happy to help, I just want to get your idea of what's a good solution before I work on it."}},"public":true,"created_at":"2015-01-01T15:01:02Z","org":{"id":29740,"login":"opscode","gravatar_id":"","url":"https://api.github.com/orgs/opscode","avatar_url":"https://avatars.githubusercontent.com/u/29740?"}}]"#
        json.parsed { result in
            XCTAssertEqual(json, result?.description)
        }
    }
    
    func test_github1() {
        let jsonData = try! Data(contentsOf: URL(fileURLWithPath: "/Volumes/Storage/large.minified.json"))
        let jsonString = String(data: jsonData, encoding: .utf8)!
        jsonString.parsed { result in
            guard let result = result else { return XCTFail() }
            try! result.description.write(toFile: "/tmp/spanker_failed.json", atomically: true, encoding: .utf8)
            XCTAssertEqual(jsonString.lengthOfBytes(using: .utf8), result.description.count)
            //XCTAssertEqual(jsonString, result?.description)
        }
    }
    
    func test_compliance0() {
        jsonDocument.parsed { result in
            XCTAssertEqual(jsonDocument, result?.description)
        }
    }
    
    func test_many() {
        let jsons = [
            jsonDocument,
            jsonTextSeries,
            jsonNumberSeries,
            #"{"store":{"book":[{"category":"reference","author":"Nigel Rees","title":"Sayings of the Century","price":8.95,"address":{"street":"fleet street","city":"London"}},{"category":"fiction","author":"Evelyn Waugh","title":"Sword of Honour","price":12.9,"address":{"street":"Baker street","city":"London"}},{"category":"fiction","author":"J. R. R. Tolkien","title":"The Lord of the Rings","isbn":"0-395-19395-8","price":22.99,"address":{"street":"Svea gatan","city":"Stockholm"}}],"bicycle":{"color":"red","price":19.95,"address":{"street":"Söder gatan","city":"Stockholm"},"items":[["A","B","C"],1,2,3,4,5]}}}"#,
            #"{"data":{"people":[{"name":"Rocco","age":42},{"name":"John","age":12},{"name":"Elizabeth","age":35},{"name":"Victoria","age":85}]}}"#,
            #"{"access_token":"aex-0u-7Yq09sBls123456789","expires_in":2678400,"token_type":"Bearer","scope":"identity","refresh_token":"CayptzsmZ_MejrKgNtAF8ka36123456789","version":"0.0.1"}"#,
            #"{"data":{"attributes":{"about":null,"created":"2021-12-19T18:06:51.000+00:00","first_name":"John","full_name":"John Doe","image_url":"https://www.example.com/image.png","last_name":"Doe","thumb_url":"https://www.example.com/image.png","url":"https://www.example.com/user?u=234576235","vanity":null},"id":"234576235","type":"user"},"links":{"self":"https://www.example.com/api/oauth2/v2/user/234576235"}}"#
        ]
        for json in jsons {
            json.parsed { result in
                XCTAssertEqual(json, result?.description)
            }
        }
    }
    
}
