module potatoes_vault::vault {

    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::sui::{SUI};
    use sui::vec_set::{Self, VecSet};

    public struct VAULT has drop {}

    public struct Vault has key {
        id: UID,
        balance: Balance<SUI>,
        blacklist: VecSet<ID>,
        max_claim_amount_per_epoch: u64,
    }

    public struct AdminCap has key, store {
        id: UID,
    }

    public struct PotatoCap has key, store {
        id: UID,
        last_epoch_claimed: u64,
        total_claimed: u64,
    }

    const EPotatoCapBlacklisted: u64 = 0;
    const EMaxClaimAmountExceeded: u64 = 1;
    const EAlreadyClaimedInEpoch: u64 = 2;

    fun init(
        _otw: VAULT,
        ctx: &mut TxContext,
    ) {
        let admin_cap = AdminCap {
            id: object::new(ctx),
        };
        let vault = Vault {
            id: object::new(ctx),
            balance: balance::zero(),
            blacklist: vec_set::empty(),
            max_claim_amount_per_epoch: 100_000_000_000,
        };
        transfer::public_transfer(admin_cap, ctx.sender());
        transfer::share_object(vault);
    }

    public fun add(
        vault: &mut Vault,
        coin: Coin<SUI>,
    ) {
        vault.balance.join(coin.into_balance());
    }

    public fun claim(
        cap: &mut PotatoCap,
        vault: &mut Vault,
        amount: u64,
        ctx: &mut TxContext,
    ): Coin<SUI> {
        assert!(!vault.blacklist.contains(cap.id.as_inner()), EPotatoCapBlacklisted);
        assert!(cap.last_epoch_claimed != ctx.epoch(), EAlreadyClaimedInEpoch);
        assert!(amount <= vault.max_claim_amount_per_epoch, EMaxClaimAmountExceeded);
        
        cap.last_epoch_claimed = ctx.epoch();
        cap.total_claimed = cap.total_claimed + amount;
        
        let balance = vault.balance.split(amount);
        coin::from_balance(balance, ctx)
    }

    public fun issue_potato_cap(
        _: &AdminCap,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        let cap = PotatoCap {
            id: object::new(ctx),
            last_epoch_claimed: 0,
            total_claimed: 0,
        };
        transfer::public_transfer(cap, recipient);
    }

    public fun add_to_blacklist(
        _: &AdminCap,
        vault: &mut Vault,
        potato_cap_id: ID,
    ) {
        vault.blacklist.insert(potato_cap_id);
    }

    public fun remove_from_blacklist(
        _: &AdminCap,
        vault: &mut Vault,
        potato_cap_id: ID,
    ) {
        vault.blacklist.remove(&potato_cap_id);
    }

    public fun set_max_claim_amount(
        _: &AdminCap,
        vault: &mut Vault,
        amount: u64,
    ) {
        vault.max_claim_amount_per_epoch = amount;
    }

    public fun destroy_potato_cap(
        cap: PotatoCap,
    ) {
        let PotatoCap {
            id,
            ..
        } = cap;
        id.delete();
    }

    public fun destroy_vault(
        cap: AdminCap,
        vault: Vault,
        ctx: &mut TxContext,
    ): Coin<SUI> {
        let Vault {
            id,
            balance,
            ..,
        } = vault;
        id.delete();
        let AdminCap {
            id,
            ..,
        } = cap;
        id.delete();
        coin::from_balance(balance, ctx)
    }
}