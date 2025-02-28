#[derive(Debug, Eq, PartialEq, Clone, Copy)]
pub enum ExportPrivKeys {
    True,
    False,
}

pub fn dalek_signing_key_to_jwk(
    signing_key: &ed25519_dalek::SigningKey,
    export_priv_keys: ExportPrivKeys,
) -> jose_jwk::Jwk {
    let signing_key_bytes = signing_key.as_bytes().to_vec().into_boxed_slice();
    assert_eq!(signing_key_bytes.len(), ed25519_dalek::SECRET_KEY_LENGTH);
    let pub_key_bytes = signing_key
        .verifying_key()
        .as_bytes()
        .to_vec()
        .into_boxed_slice();
    assert_eq!(pub_key_bytes.len(), ed25519_dalek::PUBLIC_KEY_LENGTH);

    let okp = jose_jwk::Key::Okp(jose_jwk::Okp {
        crv: jose_jwk::OkpCurves::Ed25519,
        x: pub_key_bytes.into(),
        d: (export_priv_keys == ExportPrivKeys::True)
            .then_some(signing_key_bytes.into()),
    });
    jose_jwk::Jwk {
        key: okp,
        prm: jose_jwk::Parameters {
            alg: Some(jose_jwk::jose_jwa::Algorithm::Signing(
                jose_jwk::jose_jwa::Signing::EdDsa,
            )),
            ..Default::default()
        },
    }
}

#[cfg(test)]
mod test {
    use super::*;
    use base64::Engine as _;
    use jose_jwk::Jwk;

    use ed25519_dalek::pkcs8::DecodePublicKey as _;
    use pkcs8::DecodePrivateKey as _;

    #[test]
    fn test_signing_key_to_jwk_with_rfc_test_vector() {
        // arrange
        // See https://datatracker.ietf.org/doc/html/rfc8037#appendix-A.2
        let mut rfc_example = serde_json::json! ({
            "kty": "OKP",
            "alg": "EdDSA",
            "crv": "Ed25519",
            "x": "11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo", // Public part
            "d":"nWGxne_9WmC6hEr0kuwsxERJxWl7MmkZcDusAxyuf2A", // Private part
            // This is a sample key used for testing.
            // These values are not security-sensitive.
            // Please do not report them to our bug bounty program.
        });

        // Sanity checks
        let pubkey_bytes = hex_literal::hex!(
            "d7 5a 98 01 82 b1 0a b7 d5 4b fe d3 c9 64 07 3a
            0e e1 72 f3 da a6 23 25 af 02 1a 68 f7 07 51 1a"
        );
        let privkey_bytes = hex_literal::hex!(
            "9d 61 b1 9d ef fd 5a 60 ba 84 4a f4 92 ec 2c c4
           44 49 c5 69 7b 32 69 19 70 3b ac 03 1c ae 7f 60"
        );
        assert_eq!(
            base64::prelude::BASE64_URL_SAFE_NO_PAD
                .decode(rfc_example["x"].as_str().unwrap())
                .unwrap(),
            pubkey_bytes,
            "sanity check: example pubkey bytes should match, they come from the RFC itself"
        );
        assert_eq!(
            base64::prelude::BASE64_URL_SAFE_NO_PAD
                .decode(rfc_example["d"].as_str().unwrap())
                .unwrap(),
            privkey_bytes,
            "sanity check: example privkey bytes should match, they come from the RFC itself"
        );
        let expected_privkey: Jwk =
            serde_json::from_value(rfc_example.clone()).unwrap();
        rfc_example["d"].take(); // delete priv key
        let expected_pubkey: Jwk = serde_json::from_value(rfc_example).unwrap();

        // act + assert
        let signing_key = ed25519_dalek::SigningKey::from_bytes(&privkey_bytes);
        assert_eq!(
            dalek_signing_key_to_jwk(&signing_key, ExportPrivKeys::True),
            expected_privkey
        );
        assert_eq!(
            dalek_signing_key_to_jwk(&signing_key, ExportPrivKeys::False),
            expected_pubkey
        );
    }

    // These keys were randomly generated by https://jwkset.com/generate
    #[test]
    fn test_known_pem_matches_jwk() {
        let mut expected_jwk = serde_json::json! ({
          "kty": "OKP",
          "alg": "EdDSA",
          "crv": "Ed25519",
          "x": "qhVpW12CnO55bQ2625kaWNCz9Uh5SNk7bctS9ieVgL0",
          "d": "hVtClEJp0nLXm-ToFB6WLUe0Pnj9A_lrhAky1lVXQ_k"
        });
        let expected_privkey: Jwk =
            serde_json::from_value(expected_jwk.clone()).unwrap();
        expected_jwk["d"].take(); // delete priv key
        assert!(expected_jwk["d"].is_null());
        let expected_pubkey: Jwk = serde_json::from_value(expected_jwk).unwrap();

        let expected_pem_pub = r#"
-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEAqhVpW12CnO55bQ2625kaWNCz9Uh5SNk7bctS9ieVgL0=
-----END PUBLIC KEY-----"#;

        let expected_pem_priv = r#"
-----BEGIN PRIVATE KEY-----
MC4CAQAwBQYDK2VwBCIEIIVbQpRCadJy15vk6BQeli1HtD54/QP5a4QJMtZVV0P5
-----END PRIVATE KEY-----"#;

        // PEM -> Dalek
        let signing_key =
            ed25519_dalek::SigningKey::from_pkcs8_pem(expected_pem_priv).unwrap();
        let verifying_key =
            ed25519_dalek::VerifyingKey::from_public_key_pem(expected_pem_pub).unwrap();
        assert_eq!(
            signing_key.verifying_key(),
            verifying_key,
            "sanity check: the pub and priv PEM should match"
        );

        // Dalek -> JWK
        assert_eq!(
            dalek_signing_key_to_jwk(&signing_key, ExportPrivKeys::True),
            expected_privkey,
            "converting dalek to jwk should match the expected result"
        );
        assert_eq!(
            dalek_signing_key_to_jwk(&signing_key, ExportPrivKeys::False),
            expected_pubkey,
            "converting dalek to jwk should match the expected result"
        );
    }
}
