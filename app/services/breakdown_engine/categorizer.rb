# frozen_string_literal: true

module BreakdownEngine
  class Categorizer
    def initialize(category)
      @category = category
    end

    def run
      travel = %w(taxicabs_limousines airlines_air_carriers commuter_transport_and_ferries hotels_motels_and_resorts travel_agencies_tour_operators service_stations automated_fuel_dispensers parking_lots_garages passenger_railways bus_lines car_rental_agencies transportation_services truck_utility_trailer_rentals)
      food = %w(eating_places_restaurants fast_food_restaurants grocery_stores_supermarkets miscellaneous_food_stores caterers drinking_places bakeries package_stores_beer_wine_and_liquor)
      shopping = %w(book_stores miscellaneous_specialty_retail discount_stores wholesale_clubs home_supply_warehouse_stores drug_stores_and_pharmacies miscellaneous_general_merchandise department_stores hardware_stores gift_card_novelty_and_souvenir_shops industrial_supplies variety_stores used_merchandise_and_secondhand_stores furniture_home_furnishings_and_equipment_stores_except_appliances record_stores sporting_goods_stores books_periodicals_and_newspapers plumbing_heating_equipment_and_supplies news_dealers_and_newsstands hardware_equipment_and_supplies)
      apparel = %w(miscellaneous_apparel_and_accessory_shops mens_womens_clothing_stores family_clothing_stores)
      automobiles = %w(automotive_parts_and_accessories_stores)
      arts = %w(artists_supply_and_craft_shops)
      entertainment = %w(hobby_toy_and_game_shops digital_goods_games theatrical_ticket_agencies motion_picture_theaters miscellaneous_recreation_services cable_satellite_and_other_pay_television_and_radio)
      stationary = %w(stationery_stores_office_and_school_supply_stores stationary_office_supplies_printing_and_writing_paper)
      tech = %w(electronics_stores computer_software_stores computer_programming computer_network_services digital_goods_large_volume digital_goods_applications computers_peripherals_and_software electrical_parts_and_equipment digital_goods_media)
      business = %w(miscellaneous_business_services professional_services insurance_underwriting_premiums information_retrieval_services legal_services_attorneys employment_temp_agencies secretarial_support_services miscellaneous_general_services quick_copy_repro_and_blueprint)
      art = %w(photographic_studios commercial_photography_art_and_graphics)
      marketing = %w(advertising_services miscellaneous_publishing_and_printing direct_marketing_other public_warehousing_and_storage direct_marketing_combination_catalog_and_retail_merchant direct_marketing_combination_catalog_and_retail_merchant direct_marketing_subscription)
      finance = %w(charitable_and_social_service_organizations_fundraising wires_money_orders non_fi_stored_value_card_purchase_load financial_institutions)
      communication = %w(telecommunication_services courier_services postal_services_government_only consulting_public_relations)
      education = %w(colleges_universities)
      misc = %w(utilities government_services medical_services civic_social_fraternal_associations membership_organizations)

      case @category
      when *travel then "Travel"
      when *food then "Food"
      when *shopping then "Shopping"
      when *apparel then "Apparel"
      when *automobiles then "Automobiles"
      when *arts then "Arts & crafts"
      when *entertainment then "Entertainment"
      when *stationary then "Stationary"
      when *tech then "Electronics"
      when *business then "Business services"
      when *art then "Art"
      when *marketing then "Marketing"
      when *finance then "Finance"
      when *education then "Education"
      when *communication then "Communication"
      when *misc then @category.humanize
      else
        @category
      end
    end

  end
end
