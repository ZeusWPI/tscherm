module idf.esp_wifi.esp_wifi_crypto_types;

@safe nothrow @nogc extern (C):

enum ESP_WIFI_CRYPTO_VERSION = 0x00000001;

/*
 * Enumeration for hash operations.
 * When WPA2 is connecting, this enum is used to
 * request a hash algorithm via crypto_hash_xxx functions.
 */
enum esp_crypto_hash_alg_t
{
  ESP_CRYPTO_HASH_ALG_MD5,
  ESP_CRYPTO_HASH_ALG_SHA1,
  ESP_CRYPTO_HASH_ALG_HMAC_MD5,
  ESP_CRYPTO_HASH_ALG_HMAC_SHA1,
  ESP_CRYPTO_HASH_ALG_SHA256,
  ESP_CRYPTO_HASH_ALG_HMAC_SHA256
}

/*
 * Enumeration for block cipher operations.
 * When WPA2 is connecting, this enum is used to request a block
 * cipher algorithm via crypto_cipher_xxx functions.
 */
enum esp_crypto_cipher_alg_t
{
  ESP_CRYPTO_CIPHER_NULL,
  ESP_CRYPTO_CIPHER_ALG_AES,
  ESP_CRYPTO_CIPHER_ALG_3DES,
  ESP_CRYPTO_CIPHER_ALG_DES,
  ESP_CRYPTO_CIPHER_ALG_RC2,
  ESP_CRYPTO_CIPHER_ALG_RC4
}

/*
 * This structure is about the algorithm when do crypto_hash operation, for detail,
 * please reference to the structure crypto_hash.
 */
// typedef struct crypto_hash esp_crypto_hash_t;
alias esp_crypto_hash_t = void;

/*
 * This structure is about the algorithm when do crypto_cipher operation, for detail,
 * please reference to the structure crypto_cipher.
 */
// typedef struct crypto_cipher esp_crypto_cipher_t;
alias esp_crypto_cipher_t = void;

/**
  * @brief The AES callback function when do WPS connect.
  *
  * @param key  Encryption key.
  * @param iv  Encryption IV for CBC mode (16 bytes).
  * @param data  Data to encrypt in-place.
  * @param data_len  Length of data in bytes (must be divisible by 16)
  */
alias esp_aes_128_encrypt_t = int function(const ubyte* key, const ubyte* iv, ubyte* data, int data_len);

/**
  * @brief The AES callback function when do WPS connect.
  *
  * @param key  Decryption key.
  * @param iv  Decryption IV for CBC mode (16 bytes).
  * @param data  Data to decrypt in-place.
  * @param data_len  Length of data in bytes (must be divisible by 16)
  *
  */
alias esp_aes_128_decrypt_t = int function(const ubyte* key, const ubyte* iv, ubyte* data, int data_len);

/**
  * @brief The AES callback function when do STA connect.
  *
  * @param kek  16-octet Key encryption key (KEK).
  * @param n  Length of the plaintext key in 64-bit units;
  * @param plain  Plaintext key to be wrapped, n * 64 bits
  * @param cipher  Wrapped key, (n + 1) * 64 bits
  *
  */
alias esp_aes_wrap_t = int function(const ubyte* kek, int n, const ubyte* plain, ubyte* cipher);

/**
  * @brief The AES callback function when do STA connect.
  *
  * @param kek  16-octet Key decryption key (KEK).
  * @param n  Length of the plaintext key in 64-bit units;
  * @param cipher  Wrapped key to be unwrapped, (n + 1) * 64 bits
  * @param plain  Plaintext key, n * 64 bits
  *
  */
alias esp_aes_unwrap_t = int function(const ubyte* kek, int n, const ubyte* cipher, ubyte* plain);

/**
  * @brief The SHA256 callback function when do WPS connect.
  *
  * @param key  Key for HMAC operations.
  * @param key_len  Length of the key in bytes.
  * @param num_elem  Number of elements in the data vector.
  * @param addr  Pointers to the data areas.
  * @param len  Lengths of the data blocks.
  * @param mac  Buffer for the hash (32 bytes).
  *
  */
alias esp_hmac_sha256_vector_t = int function(const ubyte* key, int key_len, int num_elem,
  const ubyte* addr, const int* len, ubyte* mac);

/**
  * @brief The AES callback function when do STA connect.
  *
  * @param key  Key for PRF.
  * @param key_len  Length of the key in bytes.
  * @param label  A unique label for each purpose of the PRF.
  * @param data  Extra data to bind into the key.
  * @param data_len  Length of the data.
  * @param buf  Buffer for the generated pseudo-random key.
  * @param buf_len  Number of bytes of key to generate.
  *
  */
alias esp_sha256_prf_t = int function(const ubyte* key, int key_len, const char* label,
  const ubyte* data, int data_len, ubyte* buf, int buf_len);

/**
 * @brief HMAC-MD5 over data buffer (RFC 2104)'
 *
 * @key: Key for HMAC operations
 * @key_len: Length of the key in bytes
 * @data: Pointers to the data area
 * @data_len: Length of the data area
 * @mac: Buffer for the hash (16 bytes)
 * Returns: 0 on success, -1 on failure
 */
alias esp_hmac_md5_t = int function(const ubyte* key, uint key_len, const ubyte* data,
  uint data_len, ubyte* mac);

/**
 * @brief HMAC-MD5 over data vector (RFC 2104)
 *
 * @key: Key for HMAC operations
 * @key_len: Length of the key in bytes
 * @num_elem: Number of elements in the data vector
 * @addr: Pointers to the data areas
 * @len: Lengths of the data blocks
 * @mac: Buffer for the hash (16 bytes)
 * Returns: 0 on success, -1 on failure
 */
alias esp_hmac_md5_vector_t = int function(const ubyte* key, uint key_len, uint num_elem,
  const ubyte* addr, const uint* len, ubyte* mac);

/**
 * @brief HMAC-SHA1 over data buffer (RFC 2104)
 *
 * @key: Key for HMAC operations
 * @key_len: Length of the key in bytes
 * @data: Pointers to the data area
 * @data_len: Length of the data area
 * @mac: Buffer for the hash (20 bytes)
 * Returns: 0 on success, -1 of failure
 */
alias esp_hmac_sha1_t = int function(const ubyte* key, uint key_len, const ubyte* data,
  uint data_len, ubyte* mac);

/**
 * @brief HMAC-SHA1 over data vector (RFC 2104)
 *
 * @key: Key for HMAC operations
 * @key_len: Length of the key in bytes
 * @num_elem: Number of elements in the data vector
 * @addr: Pointers to the data areas
 * @len: Lengths of the data blocks
 * @mac: Buffer for the hash (20 bytes)
 * Returns: 0 on success, -1 on failure
 */
alias esp_hmac_sha1_vector_t = int function(const ubyte* key, uint key_len, uint num_elem,
  const ubyte* addr, const uint* len, ubyte* mac);

/**
 * @brief SHA1-based Pseudo-Random Function (PRF) (IEEE 802.11i, 8.5.1.1)
 *
 * @key: Key for PRF
 * @key_len: Length of the key in bytes
 * @label: A unique label for each purpose of the PRF
 * @data: Extra data to bind into the key
 * @data_len: Length of the data
 * @buf: Buffer for the generated pseudo-random key
 * @buf_len: Number of bytes of key to generate
 * Returns: 0 on success, -1 of failure
 *
 * This function is used to derive new, cryptographically separate keys from a
 * given key (e.g., PMK in IEEE 802.11i).
 */
alias esp_sha1_prf_t = int function(const ubyte* key, uint key_len, const char* label,
  const ubyte* data, uint data_len, ubyte* buf, uint buf_len);

/**
 * @brief SHA-1 hash for data vector
 *
 * @num_elem: Number of elements in the data vector
 * @addr: Pointers to the data areas
 * @len: Lengths of the data blocks
 * @mac: Buffer for the hash
 * Returns: 0 on success, -1 on failure
 */
alias esp_sha1_vector_t = int function(uint num_elem, const ubyte* addr, const uint* len,
  ubyte* mac);

/**
 * @brief SHA1-based key derivation function (PBKDF2) for IEEE 802.11i
 *
 * @passphrase: ASCII passphrase
 * @ssid: SSID
 * @ssid_len: SSID length in bytes
 * @iterations: Number of iterations to run
 * @buf: Buffer for the generated key
 * @buflen: Length of the buffer in bytes
 * Returns: 0 on success, -1 of failure
 *
 * This function is used to derive PSK for WPA-PSK. For this protocol,
 * iterations is set to 4096 and buflen to 32. This function is described in
 * IEEE Std 802.11-2004, Clause H.4. The main construction is from PKCS#5 v2.0.
 */
alias esp_pbkdf2_sha1_t = int function(const char* passphrase, const char* ssid, uint ssid_len,
  int iterations, ubyte* buf, uint buflen);

/**
 * @brief XOR RC4 stream to given data with skip-stream-start
 *
 * @key: RC4 key
 * @keylen: RC4 key length
 * @skip: number of bytes to skip from the beginning of the RC4 stream
 * @data: data to be XOR'ed with RC4 stream
 * @data_len: buf length
 * Returns: 0 on success, -1 on failure
 *
 * Generate RC4 pseudo random stream for the given key, skip beginning of the
 * stream, and XOR the end result with the data buffer to perform RC4
 * encryption/decryption.
 */
alias esp_rc4_skip_t = int function(const ubyte* key, uint keylen, uint skip,
  ubyte* data, uint data_len);

/**
 * @brief MD5 hash for data vector
 *
 * @num_elem: Number of elements in the data vector
 * @addr: Pointers to the data areas
 * @len: Lengths of the data blocks
 * @mac: Buffer for the hash
 * Returns: 0 on success, -1 on failure
 */
alias esp_md5_vector_t = int function(uint num_elem, const ubyte* addr, const uint* len,
  ubyte* mac);

/**
 * @brief Encrypt one AES block
 *
 * @ctx: Context pointer from aes_encrypt_init()
 * @plain: Plaintext data to be encrypted (16 bytes)
 * @crypt: Buffer for the encrypted data (16 bytes)
 */
alias esp_aes_encrypt_t = void function(void* ctx, const ubyte* plain, ubyte* crypt);

/**
 * @brief Initialize AES for encryption
 *
 * @key: Encryption key
 * @len: Key length in bytes (usually 16, i.e., 128 bits)
 * Returns: Pointer to context data or %NULL on failure
 */
alias esp_aes_encrypt_init_t = void* function(const ubyte* key, uint len);

/**
 * @brief Deinitialize AES encryption
 *
 * @ctx: Context pointer from aes_encrypt_init()
 */
alias esp_aes_encrypt_deinit_t = void function(void* ctx);

/**
 * @brief Decrypt one AES block
 *
 * @ctx: Context pointer from aes_encrypt_init()
 * @crypt: Encrypted data (16 bytes)
 * @plain: Buffer for the decrypted data (16 bytes)
 */
alias esp_aes_decrypt_t = void function(void* ctx, const ubyte* crypt, ubyte* plain);

/**
 * @brief Initialize AES for decryption
 *
 * @key: Decryption key
 * @len: Key length in bytes (usually 16, i.e., 128 bits)
 * Returns: Pointer to context data or %NULL on failure
 */
alias esp_aes_decrypt_init_t = void* function(const ubyte* key, uint len);

/**
 * @brief Deinitialize AES decryption
 *
 * @ctx: Context pointer from aes_encrypt_init()
 */
alias esp_aes_decrypt_deinit_t = void function(void* ctx);

/**
 * @brief One-Key CBC MAC (OMAC1) hash with AES-128 for MIC computation
 *
 * @key: 128-bit key for the hash operation
 * @data: Data buffer for which a MIC is computed
 * @data_len: Length of data buffer in bytes
 * @mic: Buffer for MIC (128 bits, i.e., 16 bytes)
 * Returns: 0 on success, -1 on failure
 */
alias esp_omac1_aes_128_t = int function(const ubyte* key, const ubyte* data, size_t data_len,
  ubyte* mic);

/**
 * @brief Decrypt data using CCMP (Counter Mode CBC-MAC Protocol OR
 *        Counter Mode Cipher Block Chaining Message Authentication
 *        Code Protocol) which is used in IEEE 802.11i RSN standard.
 * @tk: 128-bit Temporal Key for obtained during 4-way handshake
 * @hdr: Pointer to IEEE802.11 frame headeri needed for AAD
 * @data: Pointer to encrypted data buffer
 * @data_len: Encrypted data length in bytes
 * @decrypted_len: Length of decrypted data
 * @espnow_pkt: Indicates if it's an ESPNOW packet
 * Returns: Pointer to decrypted data on success, NULL on failure
 */
alias esp_ccmp_decrypt_t = ubyte* function(const ubyte* tk, const ubyte* ieee80211_hdr,
  const ubyte* data, size_t data_len,
  size_t* decrypted_len, bool espnow_pkt);

/**
 * @brief Encrypt data using CCMP (Counter Mode CBC-MAC Protocol OR
 *        Counter Mode Cipher Block Chaining Message Authentication
 *        Code Protocol) which is used in IEEE 802.11i RSN standard.
 * @tk: 128-bit Temporal Key for obtained during 4-way handshake
 * @frame: Pointer to IEEE802.11 frame including header
 * @len: Length of the frame including header
 * @hdrlen: Length of the header
 * @pn: Packet Number counter
 * @keyid: Key ID to be mentioned in CCMP Vector
 * @encrypted_len: Length of the encrypted frame including header
 */
alias esp_ccmp_encrypt_t = ubyte* function(const ubyte* tk, ubyte* frame, size_t len, size_t hdrlen,
  ubyte* pn, int keyid, size_t* encrypted_len);

/**
 * @brief One-Key GMAC hash with AES for MIC computation
 *
 * @key: key for the hash operation
 * @keylen: key length
 * @iv: initialization vector
 * @iv_len: initialization vector length
 * @aad: aad
 * @aad_len: aad length
 * @mic: Buffer for MIC (128 bits, i.e., 16 bytes)
 * Returns: 0 on success, -1 on failure
 */
alias esp_aes_gmac_t = int function(const ubyte* key, size_t keylen, const ubyte* iv, size_t iv_len,
  const ubyte* aad, size_t aad_len, ubyte* mic);

// dfmt off
/**
  * @brief The crypto callback function structure used when do station security connect.
  *        The structure can be set as software crypto or the crypto optimized by ESP32
  *        hardware.
  */
struct wpa_crypto_funcs_t
{
  uint size;
  uint version_;
  esp_aes_wrap_t aes_wrap;                     /**< station connect function used when send EAPOL frame */
  esp_aes_unwrap_t aes_unwrap;                 /**< station connect function used when decrypt key data */
  esp_hmac_sha256_vector_t hmac_sha256_vector; /**< station connect function used when check MIC */
  esp_sha256_prf_t sha256_prf;                 /**< station connect function used when check MIC */
  esp_hmac_md5_t hmac_md5;
  esp_hmac_md5_vector_t hamc_md5_vector;
  esp_hmac_sha1_t hmac_sha1;
  esp_hmac_sha1_vector_t hmac_sha1_vector;
  esp_sha1_prf_t sha1_prf;
  esp_sha1_vector_t sha1_vector;
  esp_pbkdf2_sha1_t pbkdf2_sha1;
  esp_rc4_skip_t rc4_skip;
  esp_md5_vector_t md5_vector;
  esp_aes_encrypt_t aes_encrypt;
  esp_aes_encrypt_init_t aes_encrypt_init;
  esp_aes_encrypt_deinit_t aes_encrypt_deinit;
  esp_aes_decrypt_t aes_decrypt;
  esp_aes_decrypt_init_t aes_decrypt_init;
  esp_aes_decrypt_deinit_t aes_decrypt_deinit;
  esp_aes_128_encrypt_t aes_128_encrypt;
  esp_aes_128_decrypt_t aes_128_decrypt;
  esp_omac1_aes_128_t omac1_aes_128;
  esp_ccmp_decrypt_t ccmp_decrypt;
  esp_ccmp_encrypt_t ccmp_encrypt;
  esp_aes_gmac_t aes_gmac;
}
// dfmt on

/**
  * @brief The crypto callback function structure used in mesh vendor IE encryption. The
  *        structure can be set as software crypto or the crypto optimized by ESP32
  *        hardware.
  */
struct mesh_crypto_funcs_t
{
  esp_aes_128_encrypt_t aes_128_encrypt; /**< function used in mesh vendor IE encryption */
  esp_aes_128_decrypt_t aes_128_decrypt; /**< function used in mesh vendor IE decryption */
}
