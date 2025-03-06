/// This module manages information related to registration fees for competitions, 
/// including the handling of fee payments and validations.
module brkt_addr::registration_fee_info {
    use aptos_std::type_info::{TypeInfo};

    // Definitions
    struct RegistrationFeeInfo has store, copy {
        fee: u256,
        coin_type: TypeInfo,
    }

    /*
     * Creates a new RegistrationFeeInfo instance.
     *
     * @param fee - The registration fee.
     * @param coin_type - The type of coin used for the fee.
     * @return A new RegistrationFeeInfo instance.
     */
    public fun new(fee: u256, coin_type: TypeInfo): RegistrationFeeInfo {
        RegistrationFeeInfo {
            fee,
            coin_type,
        }
    }

    /*
     * Retrieves the fee from the given RegistrationFeeInfo struct.
     *
     * @param info - The RegistrationFeeInfo struct containing the fee information.
     * @return The fee value.
     */
    public fun get_fee(info: &RegistrationFeeInfo): u256 {
        info.fee
    }

    /*
     * Retrieves the coin_address from the given RegistrationFeeInfo struct.
     *
     * @param info - The RegistrationFeeInfo struct containing the coin_address information.
     * @return The coin type for the fee.
     */
    public fun get_coin_type(info: &RegistrationFeeInfo): TypeInfo {
        info.coin_type
    }
}
