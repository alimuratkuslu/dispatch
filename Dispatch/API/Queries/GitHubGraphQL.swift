import Foundation

enum GitHubGraphQL {
    static let pollQuery = """
    query DispatchPoll($owner: String!, $name: String!) {
      viewer {
        login
      }
      repository(owner: $owner, name: $name) {
        pullRequests(first: 20, states: [OPEN], orderBy: {field: UPDATED_AT, direction: DESC}) {
          nodes {
            id
            number
            title
            url
            headRefName
            createdAt
            updatedAt
            isDraft
            author {
              login
              avatarUrl
              __typename
            }
            reviewRequests(first: 10) {
              nodes {
                requestedReviewer {
                  ... on User {
                    login
                  }
                }
              }
            }
            comments(first: 30) {
              nodes {
                id
                body
                author {
                  login
                  avatarUrl
                  __typename
                }
                createdAt
                updatedAt
              }
            }
            reviews(last: 20) {
              nodes {
                id
                state
                body
                author {
                  login
                  avatarUrl
                  __typename
                }
                submittedAt
              }
            }
            reviewThreads(first: 30) {
              nodes {
                id
                path
                line
                isResolved
                comments(first: 10) {
                  nodes {
                    id
                    body
                    author {
                      login
                      avatarUrl
                      __typename
                    }
                    createdAt
                    outdated
                    replyTo {
                      id
                    }
                  }
                }
              }
            }
            commits(last: 1) {
              nodes {
                commit {
                  message
                  statusCheckRollup {
                    state
                  }
                }
              }
            }
          }
        }
        defaultBranchRef {
          name
          target {
            ... on Commit {
              statusCheckRollup {
                state
              }
            }
          }
        }
      }
    }
    """
}
