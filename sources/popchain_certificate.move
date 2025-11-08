module popchain::popchain_certificate;

use sui::object::{Self, ID, UID};
use sui::url::{Self, Url, new_unsafe_from_bytes};
use sui::event;
use std::string;
use sui::transfer;
use std::vector;
use sui::tx_context::{TxContext, Self};
use popchain::popchain_user::{Self, PopChainAccount};

/// Certificate tier structure with PRICE
public struct Tier has copy, drop, store {
    name: string::String,
    description: string::String,
    url: Url,
    price: u64,  // NEW: Each tier has its own price!
}

/// NFT Certificate
public struct CertificateNFT has key, store {
    id: UID,
    event_id: ID,
    tier_name: string::String,
    url: Url,
    tier_url: Url,
    issued_to: address,
    issued_at: u64,
    mint_price: u64,  // NEW: Record how much was paid
}

// ============ Tier Creation Functions ============

/// Create a custom tier with price
public fun create_tier(
    name: string::String,
    description: string::String,
    url: Url,
    price: u64,
): Tier {
    Tier {
        name,
        description,
        url,
        price,
    }
}

/// Create a tier from raw bytes
/// This is an entry function and can be called directly from transactions
public entry fun create_tier_from_bytes(
    name: vector<u8>,
    description: vector<u8>,
    url: vector<u8>,
    price: u64,
): Tier {
    Tier {
        name: string::utf8(name),
        description: string::utf8(description),
        url: new_unsafe_from_bytes(url),
        price,
    }
}

// ============ Default Tier Templates ============

/// Generate default PopChain tiers with prices
public fun default_popchain_tiers(ctx: &mut TxContext): vector<Tier> {
    let mut tiers = vector::empty<Tier>();
    
    // Tier 0: PopPass (0.01 SUI)
    vector::push_back(&mut tiers, Tier {
        name: string::utf8(b"PopPass"),
        description: string::utf8(b"Proof of attendance certificate"),
        url: new_unsafe_from_bytes(b"https://walrus.tusky.io/nzywCgr-PQkmnnp3hdQari9Olp_uc-QYmpc4cdO4P-o"),
        price: 10_000_000,  // 0.01 SUIC
    });
    
    // Tier 1: PopBadge (0.03 SUI)
    vector::push_back(&mut tiers, Tier {
        name: string::utf8(b"PopBadge"),
        description: string::utf8(b"Achievement or side quest badge"),
        url: new_unsafe_from_bytes(b"https://walrus.tusky.io/CmYARnNcHZoNL5kiZ7ISM86AEfho9zUYTJcTXJui8DM"),
        price: 30_000_000,  // 0.03 SUI
    });
    
    // Tier 2: PopMedal (0.05 SUI)
    vector::push_back(&mut tiers, Tier {
        name: string::utf8(b"PopMedal"),
        description: string::utf8(b"Recognition or distinction award"),
        url: new_unsafe_from_bytes(b"https://walrus.tusky.io/9Zg9oNmYzrIL9IfWkNGN8RiK6MVTAnoFYE7W1rLOaI0"),
        price: 50_000_000,  // 0.05 SUI
    });
    
    // Tier 3: PopTrophy (0.07 SUI)
    vector::push_back(&mut tiers, Tier {
        name: string::utf8(b"PopTrophy"),
        description: string::utf8(b"VIP or sponsor honor NFT"),
        url: new_unsafe_from_bytes(b"https://walrus.tusky.io/6vVBfxltZLyK-NcGUbEv0cm3Msq_0L2M_Y6U8AhBCz8"),
        price: 70_000_000,  // 0.07 SUI
    });
    
    tiers
}

/// Create custom tiers with specific prices
public fun create_custom_tiers(
    names: vector<vector<u8>>,
    descriptions: vector<vector<u8>>,
    urls: vector<vector<u8>>,
    prices: vector<u64>,
): vector<Tier> {
    let mut tiers = vector::empty<Tier>();
    let len = vector::length(&names);
    let mut i = 0;
    
    while (i < len) {
        vector::push_back(&mut tiers, Tier {
            name: string::utf8(*vector::borrow(&names, i)),
            description: string::utf8(*vector::borrow(&descriptions, i)),
            url: new_unsafe_from_bytes(*vector::borrow(&urls, i)),
            price: *vector::borrow(&prices, i),
        });
        i = i + 1;
    };
    
    tiers
}

// ============ Tier Getters ============

/// Get tier price
public fun get_tier_price(tier: &Tier): u64 {
    tier.price
}

/// Get tier name
public fun get_tier_name(tier: &Tier): string::String {
    tier.name
}

// ============ Certificate Minting ============

/// Mint a certificate NFT with tier price tracking
public fun mint_certificate(
    event_id: ID,
    url: Url,
    tier: Tier,
    attendee_account: &mut PopChainAccount,
    service_wallet_address: address,
    ctx: &mut TxContext
): ID {
    let now = sui::tx_context::epoch_timestamp_ms(ctx);
    let owner_address = popchain_user::get_owner(attendee_account);
    
    let cert = CertificateNFT {
        id: object::new(ctx),
        event_id,
        tier_name: tier.name,
        url: url,
        tier_url: tier.url,
        issued_to: owner_address,
        issued_at: now,
        mint_price: tier.price,  // Record the price paid
    };
    
    let cert_id = object::id(&cert);

    if (owner_address == @0x0) {
        transfer::public_transfer(cert, service_wallet_address);
    } else {
        transfer::public_transfer(cert, owner_address);
    };
    
    popchain_user::add_certificate(attendee_account, cert_id);
    
    event::emit(CertificateMinted {
        certificate_id: cert_id,
        event_id,
        tier_name: tier.name,
        issued_to: owner_address,
        issued_at: now,
        mint_price: tier.price,
    });
    
    cert_id
}

// ============ Certificate Getters ============

public fun get_event_id(cert: &CertificateNFT): ID {
    cert.event_id
}

public fun get_certificate_tier_name(cert: &CertificateNFT): string::String {
    cert.tier_name
}

public fun get_metadata_url(cert: &CertificateNFT): Url {
    cert.url
}

public fun get_issued_to(cert: &CertificateNFT): address {
    cert.issued_to
}

public fun get_issued_at(cert: &CertificateNFT): u64 {
    cert.issued_at
}

public fun get_mint_price(cert: &CertificateNFT): u64 {
    cert.mint_price
}

// ============ Certificate Transfer ============

public entry fun transfer_certificate_to_wallet(
    account: &mut PopChainAccount,
    certificate: CertificateNFT,
    _ctx: &mut TxContext
) {
    use popchain::popchain_errors;
    
    let owner_address = popchain_user::get_owner(account);
    assert!(owner_address != @0x0, popchain_errors::e_invalid_address());
    
    let cert_issued_to = certificate.issued_to;
    assert!(
        cert_issued_to == @0x0 || cert_issued_to == owner_address,
        popchain_errors::e_unauthorized()
    );
    
    let cert_id = object::id(&certificate);
    let certificates = popchain_user::get_certificates(account);
    let mut found = false;
    let mut i = 0;
    let len = vector::length(&certificates);
    while (i < len) {
        if (*vector::borrow(&certificates, i) == cert_id) {
            found = true;
            break
        };
        i = i + 1;
    };
    assert!(found, popchain_errors::e_unauthorized());
    
    transfer::public_transfer(certificate, owner_address);
    
    event::emit(CertificateTransferredToWallet {
        certificate_id: cert_id,
        account_id: object::id(account),
        wallet_address: owner_address,
    });
}

// ============ Events ============

public struct CertificateMinted has copy, drop {
    certificate_id: ID,
    event_id: ID,
    tier_name: string::String,
    issued_to: address,
    issued_at: u64,
    mint_price: u64,  // NEW
}

public struct CertificateTransferredToWallet has copy, drop {
    certificate_id: ID,
    account_id: ID,
    wallet_address: address,
}
