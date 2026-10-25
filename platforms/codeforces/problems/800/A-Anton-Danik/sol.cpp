// Build: g++ -std=c++17 -O2 -Wall -Wextra a.cpp -o a   (add -DLOCAL for dbg output)
// Author: lobsterchops
#include <bits/stdc++.h>
using namespace std;

using ll = long long;
using vi = vector<int>;
using pii = pair<int, int>;

#define all(x) (x).begin(), (x).end()
#define rep(i, n) for (int i = 0; i < (n); ++i)

const int INF = 1e9;
const ll LINF = 1e18;
const ll MOD = 1e9 + 7;

// vi a(n); cin >> a;  fills an already-sized vector
template <class T> istream& operator>>(istream& is, vector<T>& v) {
    for (auto& x : v) is >> x;
    return is;
}

// auto a = rv(n);  sizes and reads n ints;  rv<ll>(n) reads long longs
template <class T = int> vector<T> rv(int n) {
    vector<T> v(n);
    cin >> v;
    return v;
}

// print(a) -> space-separated line
template <class T> void print(const vector<T>& v) {
    for (size_t i = 0; i < v.size(); i++) cout << v[i] << " \n"[i + 1 == v.size()];
}

void yes(){
    cout << "YES" << '\n';
}

void no(){
    cout << "NO" << '\n';
}

#ifdef LOCAL
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
    int n;
    int acount = 0;
    int dcount = 0;

    cin >> n;

    string games;

    cin >> games;

    for (int i = 0; i < n; i++){
        if (games[i] == 'A'){
            acount++;
        } else {
            dcount++;
        }
    }

    if (acount == dcount){
        cout << "Friendship";
    } else if (acount > dcount){
        cout << "Anton";
    } else {
        cout << "Danik";
    }

}

int main() {
    ios::sync_with_stdio(false);
    cin.tie(nullptr);

    solve();
}