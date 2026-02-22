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
            state
            title
            url
            headRefName
            createdAt
            updatedAt
            isDraft
            mergeable
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

    static let markReadyMutation = """
    mutation MarkReady($input: MarkPullRequestReadyForReviewInput!) {
      markPullRequestReadyForReview(input: $input) {
        pullRequest {
          id
          isDraft
        }
      }
    }
    """

    static let addThreadReplyMutation = """
    mutation AddReply($input: AddPullRequestReviewThreadReplyInput!) {
      addPullRequestReviewThreadReply(input: $input) {
        comment {
          id
          body
        }
      }
    }
    """
}
