#import "RVLocalModel.h"
#include <llama/llama.h>
#include <atomic>
#include <vector>
#include <string>
#include <chrono>

@implementation RVLocalModel {
    llama_model *_model;
    llama_context *_context;
    std::atomic<bool> _cancelled;
}
static NSError *RVError(NSString *message) {
    return [NSError errorWithDomain:@"RomanVoice.LocalModel" code:1 userInfo:@{NSLocalizedDescriptionKey:message}];
}
- (nullable instancetype)initWithPath:(NSString *)path error:(NSError **)error {
    self = [super init]; if (!self) return nil;
    static dispatch_once_t once; dispatch_once(&once, ^{ llama_backend_init(); });
    _cancelled = false;
    auto mp = llama_model_default_params(); mp.n_gpu_layers = 99;
    _model = llama_model_load_from_file(path.UTF8String, mp);
    if (!_model) { if (error) *error = RVError(@"Das KI-Modell konnte nicht geladen werden."); return nil; }
    auto cp = llama_context_default_params(); cp.n_ctx = 8192; cp.n_batch = 512; cp.n_threads = 4; cp.n_threads_batch = 4;
    _context = llama_init_from_model(_model, cp);
    if (!_context) { if (error) *error = RVError(@"Nicht genügend Speicher für die lokale Analyse."); return nil; }
    return self;
}
- (void)dealloc { if (_context) llama_free(_context); if (_model) llama_model_free(_model); }
- (void)cancel { _cancelled = true; }
- (nullable NSString *)generate:(NSString *)prompt error:(NSError **)error {
    _cancelled = false;
    const auto *vocab = llama_model_get_vocab(_model);
    std::string input(prompt.UTF8String);
    int n = -llama_tokenize(vocab, input.c_str(), (int)input.size(), nullptr, 0, true, true);
    if (n <= 0 || n > 6000) { if (error) *error = RVError(@"Dieser zusammenhängende Textabschnitt ist zu lang. Bitte Sprecher manuell prüfen."); return nil; }
    std::vector<llama_token> tokens(n);
    llama_tokenize(vocab, input.c_str(), (int)input.size(), tokens.data(), n, true, true);
    llama_memory_clear(llama_get_memory(_context), true);
    for (int i=0; i<n; i+=512) {
        if (_cancelled) { if (error) *error = RVError(@"Analyse unterbrochen."); return nil; }
        auto batch = llama_batch_get_one(tokens.data()+i, std::min(512,n-i));
        if (llama_decode(_context, batch) != 0) { if (error) *error = RVError(@"Die lokale Analyse konnte den Text nicht verarbeiten."); return nil; }
    }
    auto *sampler = llama_sampler_init_greedy();
    std::string output;
    auto started = std::chrono::steady_clock::now();
    bool ended = false;
    for (int i=0; i<1800; i++) {
        if (_cancelled || std::chrono::steady_clock::now()-started > std::chrono::minutes(3)) break;
        auto token = llama_sampler_sample(sampler, _context, -1);
        if (llama_vocab_is_eog(vocab, token)) { ended = true; break; }
        char buffer[256]; int count = llama_token_to_piece(vocab, token, buffer, sizeof(buffer), 0, false);
        if (count > 0) output.append(buffer, count);
        auto batch = llama_batch_get_one(&token, 1);
        if (llama_decode(_context, batch) != 0) break;
    }
    llama_sampler_free(sampler);
    if (_cancelled || !ended) { if (error) *error = RVError(@"Analyse unterbrochen oder Zeitlimit erreicht. Der letzte Checkpoint bleibt erhalten."); return nil; }
    return [[NSString alloc] initWithBytes:output.data() length:output.size() encoding:NSUTF8StringEncoding];
}
@end
