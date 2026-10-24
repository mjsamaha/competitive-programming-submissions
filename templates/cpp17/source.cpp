// =============================================================================
// Competitive Programming Template (C++17)
//
// Build:  g++ -std=c++17 -O2 -Wall -Wextra template.cpp -o a
// Debug:  add -DLOCAL to enable dbg() output
// Run:    runcpp <name>   (compiles, runs, prints time)
//
// Local-only output (dbg and the timer) goes to stderr, so it never mixes with
// the program's real output.
// =============================================================================

#include <bits/stdc++.h>
using namespace std;

// ------------------------------------------------------------ Types & constants
using ll  = long long;
using pii = pair<int, int>;
using pll = pair<ll, ll>;
using vi  = vector<int>;
using vll = vector<ll>;
using vvi = vector<vi>;

constexpr int INF  = 1e9;      // int "infinity": INF + INF still fits in int
constexpr ll  LINF = 1e18;     // ll "infinity":  LINF + LINF still fits in ll
constexpr ll  MOD  = 1e9 + 7;  // or 998244353, depending on the problem

// ------------------------------------------------------------ Short-hand helpers
//   all(a)         a.begin(), a.end()      sort(all(a));
//   pb             push_back               a.pb(x);
//   sz(a)          size as int             for (int i = 0; i < sz(a); i++)
//   rep(i, n)      i = 0 .. n-1
//   rep1(i, n)     i = 1 .. n
//   per(i, n)      i = n-1 .. 0  (backwards)
#define all(x) (x).begin(), (x).end()
#define pb push_back
#define rep(i, n)  for (int i = 0; i < (n); ++i)
#define rep1(i, n) for (int i = 1; i <= (n); ++i)
#define per(i, n)  for (int i = (n) - 1; i >= 0; --i)
template <class T> int sz(const T& c) { return (int)c.size(); }

//   chmin(best, x)  best = min(best, x), returns true if it changed
//   chmax(best, x)  best = max(best, x), returns true if it changed
//   vsum(a)         sum of a as long long
//   vmax(a), vmin(a)  largest / smallest element
template <class T> bool chmin(T& a, const T& b) { return b < a && (a = b, true); }
template <class T> bool chmax(T& a, const T& b) { return a < b && (a = b, true); }
template <class T> ll vsum(const vector<T>& v) { return accumulate(all(v), 0LL); }
template <class T> T vmax(const vector<T>& v) { return *max_element(all(v)); }
template <class T> T vmin(const vector<T>& v) { return *min_element(all(v)); }

//   yes()  prints YES      no()  prints NO      yn(cond)  prints YES or NO
void yes() { cout << "YES\n"; }
void no()  { cout << "NO\n"; }
void yn(bool b) { cout << (b ? "YES\n" : "NO\n"); }

// ------------------------------------------------------------------------- I/O
// cin/cout handle pairs and vectors directly:
//   int n; cin >> n;
//   auto a = rv(n);            // reads n ints into a vector<int>
//   auto b = rv<ll>(n);        // same, as long long (also rv<string>, rv<char>, ...)
//   vi c(n); cin >> c;         // or fill an existing vector
//   pii p; cin >> p;           // reads p.first, p.second
//   vector<pii> e(m); cin >> e;  // m lines of "u v"
//   cout << a << '\n';         // space-separated
//   print(a, '\n');            // custom separator, trailing newline
template <class A, class B>
istream& operator>>(istream& is, pair<A, B>& p) { return is >> p.first >> p.second; }

template <class T>
istream& operator>>(istream& is, vector<T>& v) { for (auto& x : v) is >> x; return is; }

template <class A, class B>
ostream& operator<<(ostream& os, const pair<A, B>& p) { return os << p.first << ' ' << p.second; }

template <class T>
ostream& operator<<(ostream& os, const vector<T>& v) {
    for (int i = 0; i < sz(v); i++) { if (i) os << ' '; os << v[i]; }
    return os;
}

template <class T = int>
vector<T> rv(int n) { vector<T> v(n); cin >> v; return v; }

template <class T>
void print(const vector<T>& v, char sep = ' ') {
    for (int i = 0; i < sz(v); i++) { if (i) cout << sep; cout << v[i]; }
    cout << '\n';
}

// ----------------------------------------------------------------------- Debug
// dbg(x) prints "[x] = value" to stderr; works for pairs and vectors too.
// Compiles to nothing unless -DLOCAL is set.
#ifdef LOCAL
#define dbg(x) (cerr << "[" #x "] = " << (x) << '\n')
#else
#define dbg(x) ((void)0)
#endif

// ----------------------------------------------------------------------- Timer
// Prints "Time: X ms" to stderr when the program exits.
// Keyed on ONLINE_JUDGE (not LOCAL) so it works with no compiler flags;
// judges that define ONLINE_JUDGE (e.g. Codeforces) skip it.
#ifndef ONLINE_JUDGE
struct Timer {
    chrono::steady_clock::time_point start = chrono::steady_clock::now();
    ~Timer() {
        auto ms = chrono::duration_cast<chrono::milliseconds>(
                      chrono::steady_clock::now() - start).count();
        cerr << "\nTime: " << ms << " ms\n";
    }
} timer;
#endif

// -------------------------------------------------------------------- Solution
// Handles ONE test case. Use '\n' instead of endl (endl flushes every time).
void solve() {
    int t;
    while (--t){
    	int a, b, c;
    	cin >> a >> b >> c;

    	if (b == a+1){
    		cout << 1 << '\n';
    	} else {
    		cout << 0 << '\n';
    	}
    }
}

int main() {
    ios::sync_with_stdio(false);  // don't mix with scanf/printf after this
    cin.tie(nullptr);

    constexpr bool MULTI = false;  // true if the input starts with a test count
    int t = 1;
    if (MULTI) cin >> t;
    while (t--) solve();
    return 0;
}