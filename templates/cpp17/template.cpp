// Build: g++ -std=c++17 -O2 -Wall -Wextra a.cpp -o a   (add -DLOCAL for dbg output)
// Author: lobsterchops
#include <bits/stdc++.h>
using namespace std;

using ll = long long;
using vi = vector<int>;
using vll = vector<ll>;
using vvi = vector<vi>;
using pii = pair<int, int>;
using pll = pair<ll, ll>;
template <class T> using minpq = priority_queue<T, vector<T>, greater<T>>;  // min-heap

#define all(x) (x).begin(), (x).end()
#define rep(i, n) for (int i = 0; i < (n); ++i)
#define sz(x) ((int)(x).size())  // int size, avoids signed/unsigned warnings

const int INF = 1e9;
const ll LINF = 1e18;
const ll MOD = 1e9 + 7;

// pair<T,U> p; cin >> p;  (declared before the vector one so vector<pair> works)
template <class T, class U> istream& operator>>(istream& is, pair<T, U>& p) {
    return is >> p.first >> p.second;
}

// vi a(n); cin >> a;  fills an already-sized vector
template <class T> istream& operator>>(istream& is, vector<T>& v) {
    for (auto& x : v) is >> x;
    return is;
}

// auto a = rv(n);  sizes and reads n ints;  rv<ll>(n) reads long longs;  rv<pii>(n) reads pairs
template <class T = int> vector<T> rv(int n) {
    vector<T> v(n);
    cin >> v;
    return v;
}

// print(a) -> space-separated line
template <class T> void print(const vector<T>& v) {
    for (size_t i = 0; i < v.size(); i++) cout << v[i] << " \n"[i + 1 == v.size()];
}

// chmin(ans, x): ans = min(ans, x), returns true if ans changed
template <class T, class U> bool chmin(T& a, const U& b) { return b < a ? (a = b, true) : false; }
template <class T, class U> bool chmax(T& a, const U& b) { return a < b ? (a = b, true) : false; }

// sort + dedupe in place
template <class T> void uniq(vector<T>& v) { sort(all(v)); v.erase(unique(all(v)), v.end()); }

// ceil division for positives
template <class T> T cdiv(T a, T b) { return (a + b - 1) / b; }

void yes(){
    cout << "YES" << '\n';
}

void no(){
    cout << "NO" << '\n';
}

#ifdef LOCAL
// dbg(x) also prints pairs and containers: vector, set, multiset, map, deque, array (nesting ok)
template <class T, class U> ostream& operator<<(ostream& os, const pair<T, U>& p);  // forward decl
template <class T, class = typename T::value_type>
enable_if_t<!is_same<T, string>::value, ostream&> operator<<(ostream& os, const T& c) {
    os << '[';
    for (auto it = c.begin(); it != c.end(); ++it) os << (it == c.begin() ? "" : ", ") << *it;
    return os << ']';
}
template <class T, class U> ostream& operator<<(ostream& os, const pair<T, U>& p) {
    return os << '(' << p.first << ", " << p.second << ')';
}
#define dbg(x) (cerr << #x << " = " << (x) << '\n')
#else
#define dbg(x) ((void)0)
#endif

// prints "Time: X ms" to stderr (skipped on judges that define ONLINE_JUDGE)
#ifndef ONLINE_JUDGE
struct Timer {
    chrono::steady_clock::time_point s = chrono::steady_clock::now();
    ~Timer() {
        cerr << "\nTime: " << chrono::duration_cast<chrono::milliseconds>(
                                  chrono::steady_clock::now() - s).count() << " ms\n";
    }
} timer;
#endif

void solve() {

    
}

int main() {
    ios::sync_with_stdio(false);
    cin.tie(nullptr);

    // multi-test: uncomment the next line
    // int t; cin >> t; while (t--)
    solve();
}